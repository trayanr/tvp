project('python-interfaces', 'c')
p = import('python').find_installation(get_option('python'))
p.extension_module('answer', 'answer.c')
executable('embed', 'embed.c', dependencies: p.dependency(embed: true))
