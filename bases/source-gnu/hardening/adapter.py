"""Native GNU consumer adapter; argv arrays only, no caller text evaluation.

Response tokenization follows libiberty/argv.c buildargv (GCC 16), not shell
quoting: backslash escapes the next character even inside either kind of quote.
This independently written parser implements that documented grammar. It rejects
malformed quoting/NUL rather than forwarding an ambiguously inspected request.
"""
import os
import sys

SUPPORTED = ('bindnow', 'fortify', 'format', 'pic', 'relro', 'stackprotector', 'strictoverflow')
# GCC switches whose next word is an operand, including switch-looking operands.
OPERANDS = set('''-o -x -I -D -U -A -isystem -iquote -idirafter -include -imacros
-iprefix -iwithprefix -iwithprefixbefore -isysroot --sysroot -L -B -Xlinker
-Xassembler -Xpreprocessor -MF -MT -MQ -aux-info -dumpbase -dumpdir -dumpbase-ext
--param -specs -wrapper -iplugindir -imultilib -imultiarch -isystem-after'''.split())


def fail(message):
    raise ValueError('TVP consumer hardening: ' + message)


def tokenize(text):
    if '\0' in text:
        fail('NUL in response file')
    words, token, quote, started = [], '', '', False
    i = 0
    while i < len(text):
        c = text[i]
        if c == '\\':
            i += 1
            if i == len(text):
                fail('trailing response escape')
            token += text[i]
            started = True
        elif quote:
            if c == quote:
                quote = ''
            else:
                token += c
        elif c in "\"'":
            quote, started = c, True
        elif c in ' \t\n\r\v\f':
            if started:
                words.append(token)
                token, started = '', False
        else:
            token += c
            started = True
        i += 1
    if quote:
        fail('unterminated response quote')
    if started:
        words.append(token)
    return words


def expand(args, depth=0):
    if depth >= 64:
        fail('response nesting exceeds 63')
    result = []
    for arg in args:
        if arg.startswith('@'):
            try:
                with open(arg[1:], encoding='utf-8', errors='surrogateescape') as f:
                    text = f.read()
            except OSError:
                fail('unreadable response file: ' + arg[1:])
            result.extend(expand(tokenize(text), depth + 1))
        else:
            result.append(arg)
    return result


def options(args, linker=False):
    """Yield options with operands attached, leaving input filenames as data."""
    i = 0
    operands = {'-o', '-L', '-l', '-m', '-T', '-e', '-u', '-z', '--script', '--entry', '--dynamic-linker', '-rpath', '-rpath-link'} if linker else OPERANDS
    while i < len(args):
        arg = args[i]
        if arg == '--':
            break
        if arg in operands:
            if i + 1 == len(args):
                fail('missing operand for ' + arg)
            yield arg, args[i + 1]
            i += 2
        else:
            yield arg, None
            i += 1


def words(env, key):
    value = env.pop(key, '')
    if any(c in value for c in '\t\n\r\v\f') or (key == 'NIX_LDFLAGS' and ',' in value):
        fail('unsupported encoding in ' + key)
    return [w for w in value.split(' ') if w]


def compiler_query(option, operand):
    # Output-naming switches use the -dump prefix too; they still compile.
    if operand is not None or option.startswith(('-dumpbase=', '-dumpbase-ext=', '-dumpdir=')):
        return False
    return option.startswith(('-print', '-dump', '--print-', '--dump', '--help')) or option in ('--version', '--target-help')


def linker_arguments(opts):
    """Preserve the order of linker words embedded in GCC options."""
    for option, operand in opts:
        if option.startswith('-Wl,'):
            yield from option[4:].split(',')
        elif option == '-Xlinker':
            yield operand


def static_search(opts):
    # Library search may return to dynamic mode after a scoped static library.
    static = False
    for option, _ in opts:
        if option in ('-static', '-Bstatic', '--static', '-dn', '-non_shared'):
            static = True
        elif option in ('-Bdynamic', '-dy', '-call_shared'):
            static = False
    return static


def prepare(program, argv, environment, defaults):
    env = environment.copy()
    selected = env.pop('NIX_HARDENING_ENABLE', ' '.join(defaults)).split()
    if any(name not in SUPPORTED for name in selected):
        fail('unknown protection name')
    # With no active policy call the old tool with the EXACT old protocol/argv.
    if not selected:
        return argv, env
    compile_flags = words(env, 'NIX_CFLAGS_COMPILE')
    link_flags = words(env, 'NIX_CFLAGS_LINK')
    ld_flags = words(env, 'NIX_LDFLAGS')
    direct = program == 'ld'
    if direct:
        args = expand(ld_flags + argv)
        opts = list(options(args, linker=True))
        # GNU ld -v/-V print information AND link when inputs are present.
        query = any(a in ('--version', '--help') for a, _ in opts) or expand(argv) in (['-v'], ['-V'])
        excluded = any(a in ('-r', '--relocatable', '-static', '-Bstatic', '--static') for a, _ in opts)
        flags = []
        if not query and not excluded:
            if 'relro' in selected:
                flags += ['-z', 'relro']
            if 'bindnow' in selected:
                flags += ['-z', 'now']
        # Raw ld never consumes the compiler protocol. No compile protection claim.
        return (argv if query else flags + args), env
    # Effective order is the unchanged driver's compile, link, argv order.
    args = expand(compile_flags + argv)
    opts = list(options(args))
    query = any(compiler_query(a, operand) for a, operand in opts)
    query = query or expand(argv) == ['-v']
    if query:
        return argv, env
    compile_only = program == 'cpp' or any(a in ('-c', '--compile', '-S', '--assemble', '-E', '--preprocess', '-M', '-MM', '-fsyntax-only') for a, _ in opts)
    if not compile_only:
        link_opts = list(options(expand(link_flags)))
        if any(a in ('-c', '--compile', '-S', '--assemble', '-E', '--preprocess', '-M', '-MM', '-fsyntax-only') or compiler_query(a, operand) for a, operand in link_opts):
            fail('mode-changing NIX_CFLAGS_LINK words are unsupported')
        args = expand(compile_flags + link_flags + argv)
        opts = list(options(args))
    # These interfaces can rewrite flags/macros behind the policy analyzer.
    # Fail closed on active policies; callers can explicitly select the old base.
    if any(a in ('-specs', '-wrapper', '-Xpreprocessor', '-imacros') or a.startswith(('-specs=', '--specs=', '-fplugin', '-Wp,')) for a, _ in opts):
        fail('opaque specs/plugin/preprocessor options are unsupported with an active policy')
    # Retain ABI/static-PIE rejection even when options came through response files.
    if any(a in ('-static-pie', '-m16', '-m32', '-mx32', '-mmusl', '-mbionic', '-muclibc') for a, _ in opts):
        fail('unsupported native GNU ABI/static PIE mode')
    optimization = '0'
    explicit_fortify = False
    language = None
    assembler = False
    inputs = False
    for a, operand in opts:
        if a == '-x':
            language = operand
        elif a.startswith('-x'):
            language = a[2:]
        if a.startswith('-O'):
            optimization = a[2:] or '1'
        macro = operand if a in ('-D', '-U') else a[2:] if a.startswith(('-D', '-U')) else ''
        if macro.split('=', 1)[0] == '_FORTIFY_SOURCE':
            explicit_fortify = True
        if operand is None and (not a.startswith('-') or a == '-'):
            inputs = True
            if language in (None, 'none'):
                assembler = assembler or a.endswith(('.s', '.S'))
            else:
                assembler = assembler or language.startswith('assembler')
    # Unknown optimization modes must not be guessed for fortification.
    if optimization not in ('0', '1', '2', '3', 'g', 's', 'z', 'fast'):
        fail('unsupported optimization mode for policy analysis')
    flags = []
    if not assembler and (inputs or not (language or '').startswith('assembler')):
        if 'pic' in selected:
            flags += ['-fPIC']
        if 'stackprotector' in selected:
            flags += ['-fstack-protector-strong']
        if 'strictoverflow' in selected:
            flags += ['-fno-strict-overflow']
        if 'format' in selected:
            flags += ['-Wformat', '-Wformat-security', '-Werror=format-security']
        if 'fortify' in selected and optimization != '0' and not explicit_fortify:
            flags += ['-D_FORTIFY_SOURCE=2']
    link_opts = list(options(list(linker_arguments(opts)) + ld_flags, linker=True))
    excluded = any(a in ('-static', '-r', '--relocatable') for a, _ in opts)
    excluded = excluded or any(a in ('-r', '--relocatable') for a, _ in link_opts) or static_search(link_opts)
    if not compile_only and not excluded:
        if 'relro' in selected:
            flags += ['-Wl,-z,relro']
        if 'bindnow' in selected:
            flags += ['-Wl,-z,now']
    # Flatten inspected response files once. The old driver's parser cannot
    # reinterpret their quoting or append environment contributions a second time.
    return flags + args + ([] if compile_only else [x for a in ld_flags for x in ('-Xlinker', a)]), env


def main():
    program = PROGRAM.removeprefix('x86_64-unknown-linux-gnu-')
    program = {'cc': 'gcc', 'c++': 'g++'}.get(program, program)
    try:
        args, env = prepare(program, sys.argv[1:], os.environ, DEFAULTS)
    except ValueError as error:
        print(error, file=sys.stderr)
        return 64
    executable = os.path.join(BINTOOLS if program == 'ld' else DRIVER, program)
    os.execve(executable, [executable] + args, env)


if __name__ == '__main__':
    sys.exit(main())
