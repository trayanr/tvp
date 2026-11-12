"""One compile-free fixture suite for all source protocol groups; no qualification."""
import copy
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import sys
import tarfile
import tempfile


def load(path):
    spec = importlib.util.spec_from_file_location('real_classifier',path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main(ordinary):
    m = load(ordinary/'classify.py')
    data = m.read_record(ordinary/'source-contracts.json')
    assert len(data['sources']) == 68 and len(data['groups']) == 8
    versions = [v for g in data['groups'] for v in g['versions']]
    assert len(set(versions)) == len(versions) == 68
    for version, entry in data['sources'].items():
        group = next(g for g in data['groups'] if g['id'] == entry['protocol'])
        assert version in group['versions']
        inventory = m.checker_inventory(group)
        assert len({tuple(x) for x in inventory}) == len(inventory)
        assert entry['fuzz'] == (tuple(map(int,version.split('.'))) >= (2,9,11))
        assert entry['roles']['Makefile.am'] and not entry['runtimeQualified']
        modern = tuple(map(int,version.split('.'))) >= (2,12,0)
        result = m.inspect_unit('testdict','' if modern else 'dictionary tests succeeded 20000 strings\n','',group,{}, {},data['bodies'])
        assert result['bodySuccess']
        assert m.inspect_unit('testchar',data['bodies']['testchar'],'',group,{}, {},data['bodies'])['bodySuccess']
    def rejects(fn):
        try: fn()
        except (ValueError,OSError): return
        raise AssertionError('accepted unsafe fixture')
    assert 'LIBXML_FAKE_ENABLED' not in m.feature_macros('#ifndef __XML_VERSION_H__\n#define __XML_VERSION_H__\n#if 0\n#define LIBXML_FAKE_ENABLED\n#endif\n#endif\n')
    rejects(lambda:m.feature_macros('#if UNKNOWN\n#define LIBXML_FAKE_ENABLED\n#endif\n'))
    rejects(lambda:m.feature_macros('#if 1\n'))
    rejects(lambda:m.selected_descriptions('testDescriptions[] = {\n#ifdef UNKNOWN_SOURCE_FEATURE\n { \"hidden\", fn },\n#endif\n};', m.feature_macros('')))
    legacy = 'static int\ntestlibxml2(void)\n{\n int test_ret = 0;\n test_ret += test_second();\n test_ret += test_first();\n}\n'
    for name,count in [('first',1),('second',2)]:
        legacy += f'static int\ntest_{name}(void) {{\n int test_ret = 0;\n if (quiet == 0) printf("Testing {name} : {count} of {count} functions ...\\n");\n}}\n'
    progress=m.legacy_api_progress(legacy)
    assert progress.startswith('Testing second')
    old_group=next(g for g in data['groups'] if g['testapiProtocol'] != 'silent')
    good=progress+'Total: 3 functions, 5 tests, 0 errors\n'
    assert m.inspect_unit('testapi',good,'',old_group,{'testapi.c':legacy},{},data['bodies'])['bodySuccess']
    rejects(lambda:m.inspect_unit('testapi',good+'testapi leaked 4 bytes in 1 blocks\n','',old_group,{'testapi.c':legacy},{},data['bodies']))
    rejects(lambda:m.framed_events('not framed\n', ['known']))
    events=m.framed_events('\n------------\nknown\nFailed failure words in diagnostic tail\n',['known'])
    assert len(events)==1 and events[0]['event']=='known'
    rejects(lambda:m.framed_events('\n------------\nunknown\n',['known']))
    cases=[]
    with tempfile.TemporaryDirectory(prefix='libxml-real-contract-') as tmp:
        tmp=Path(tmp)
        artifact=tmp/'artifact';raw=artifact/'nix-support/upstream-raw';commands=raw/'commands'
        commands.mkdir(parents=True)
        header=artifact/'include/libxml2/libxml/xmlversion.h';header.parent.mkdir(parents=True)
        header.write_text('#ifndef __XML_VERSION_H__\n#define __XML_VERSION_H__\n#define LIBXML_DOTTED_VERSION "2.15.3"\n#define LIBXML_XPATH_ENABLED\n#define LIBXML_ICONV_ENABLED\n#define LIBXML_MODULES_ENABLED\n#define LIBXML_READER_ENABLED\n#define LIBXML_SCHEMAS_ENABLED\n#define LIBXML_RELAXNG_ENABLED\n#define LIBXML_CATALOG_ENABLED\n#if 0\n#define LIBXML_ICU_ENABLED\n#endif\n#endif\n')
        sources={'Makefile.am':'# synthetic protocol fixture\n','testrecurse.c':'testDescriptions[] = {\n { "recurse", fn, NULL },\n};\n','runtest.c':'testDescriptions[] = {\n { "runtime", fn, NULL },\n};\n','runsuite.c':'test_log("Failed to validate valid instance line %ld\\n", n);\ntest_log("Failed to detect incorrect RNG line %ld\\n", n);\n'}
        archive=tmp/'source.tar.xz'
        with tarfile.open(archive,'w:xz') as t:
            for role,text in sources.items():
                body=text.encode();info=tarfile.TarInfo('libxml2-2.15.3/'+role);info.size=len(body);t.addfile(info,io.BytesIO(body))
        contracts=copy.deepcopy(data)
        entry=contracts['sources']['2.15.3']
        entry.update(archiveSha256=m.digest(archive.read_bytes()),roles={r:m.digest(s.encode()) for r,s in sources.items()},corpusMembers=0,corpusInventorySha256=m.digest(b'[]'))
        contract_file=tmp/'contracts.json';contract_file.write_text(json.dumps(contracts))
        adapter=tmp/'capture-command.py';adapter.write_bytes((ordinary/'capture-command.py').read_bytes())
        binding={'schema':1,'version':'2.15.3','source':str(archive),'sourceCwd':'/build/workspace/source','system':'x86_64-linux','features':{'doCheck':True,'xpath':True,'lzma':False,'http':False,'icu':False,'iconv':True},'runtime':{'shell':'/fixture/bash','libraries':[]},'make':'/fixture/make','bash':'/fixture/bash','python':'/fixture/python','commandCaptureHelper':'/fixture/capture-command.py'}
        binding['commandCaptureHelper']=str(adapter)
        group=next(g for g in data['groups'] if '2.15.3' in g['versions'])
        outputs={'testchar':data['bodies']['testchar'],'testModule':'Success!\n','testrecurse':'## recurse\nTotal 7 tests, no errors\n','runtest':'## runtime\nTotal 11 tests, no errors\n','runxmlconf':'Ran 0 tests, no errors\nTotal 0 tests, no errors\n','runsuite':'## XML Schemas datatypes test suite from James Clark\nRan 7 tests, 3 errors, 0 leaks\n3 errors were expected\n## Relax NG test suite from James Clark\nRan 5 tests, no errors\n## Relax NG test suite for libxml2\nRan 2 tests, no errors\n'+'Ran 0 tests (0 schemata), no errors\n'*3+'Total 14 tests, no errors\n'}
        errors={'testparser':data['bodies']['parser21503'],'runxmlconf':'./xmlconf/xmlconf.xml is missing \n  you need to fetch and extract the\n  latest XML Conformance Test Suites\n  http://www.w3.org/XML/Test/xmlts20080827.tar.gz\n  see http://www.w3.org/XML/Test/ for information\n','runsuite':''.join('Failed to parse xstc/Tests/Metadata/'+x+'.testSet\n' for x in ['NISTXMLSchemaDatatypes','SunXMLSchema1-0-20020116','MSXMLSchema1-0-20020116'])}
        unit_paths={}
        for argv in m.checker_inventory(group):
            record={'argv':argv,'cwd':binding['sourceCwd'],'exit':0}
            unit=commands/(m.digest(json.dumps([record['cwd'],argv]).encode())+'-0');unit.mkdir();name=argv[0][2:];unit_paths[name]=unit
            (unit/'exit.json').write_text(json.dumps(record));(unit/'stdout').write_text(outputs.get(name,''));(unit/'stderr').write_text(errors.get(name,''))
        outer={'argv':['/fixture/make/bin/make','-j32','SHELL=/fixture/bash/bin/bash','CHECKER=/fixture/python/bin/python3 -B '+str(adapter),'check'],'exit':0}
        (raw/'exit.json').write_text(json.dumps(outer));(raw/'stdout').write_text('Total 14 tests, no errors\n')
        (raw/'runxmlconf.log').write_text('')
        (raw/'runsuite.log').write_text(''.join('\n------------\nFailed to validate valid instance line '+str(n)+'\ndiagnostic failure words\n' for n in [1,2,3])+''.join('\n------------\nFailed to detect incorrect RNG line '+str(n)+'\n' for n in [4,5,6,7,8,9,10]))
        def inspect(): return m.inspect(raw,'2.15.3',contract_file,binding,artifact)
        baseline=inspect()
        assert len(baseline['units'])==10 and baseline['protocolValid'] and not baseline['strictPass'],baseline
        assert sum(u['bodySuccess'] for u in baseline['units'].values())==8
        assert len(baseline['runsuiteEvents'])==10
        cases.append('recognized structure retains operational failures and gaps')
        def body_rejected(name):
            return lambda report: (not report['units'][name]['protocolValid']
                                   and not report['units'][name]['bodySuccess'])
        def structural_rejection(report):
            return bool(report['structuralErrors'])
        def mutate(path,body,label,expected_rejection):
            original=path.read_bytes();path.write_bytes(body)
            try:
                result=inspect()
            finally:
                path.write_bytes(original)
            assert not result['strictPass'],label
            assert expected_rejection(result),(label,result)
            cases.append(label)
        mutate(raw/'exit.json',b'{"argv":[],"exit":0,"exit":0}', 'duplicate JSON keys',structural_rejection)
        mutate(unit_paths['testchar']/'exit.json',b'{"argv":["./testchar"],"cwd":"/build/workspace/source","exit":true}', 'boolean exit',structural_rejection)
        rec=json.loads((unit_paths['testchar']/'exit.json').read_text());rec['cwd']='/wrong'
        mutate(unit_paths['testchar']/'exit.json',json.dumps(rec).encode(),'wrong cwd',structural_rejection)
        rec['cwd']=binding['sourceCwd'];rec['argv']=['./testchar','-q']
        mutate(unit_paths['testchar']/'exit.json',json.dumps(rec).encode(),'wrong argv',structural_rejection)
        mutate(unit_paths['testchar']/'stderr',b'failure with exit0\n','testchar failure stderr',body_rejected('testchar'))
        mutate(unit_paths['testModule']/'stdout',b'./testModule : Module support not compiled in\n','enabled module replaced with stub',body_rejected('testModule'))
        mutate(unit_paths['testparser']/'stderr',data['bodies']['parser21503'].replace('imported.xsd','other.xsd').encode(),'changed parser diagnostic',body_rejected('testparser'))
        for body,label in [(b'## recurse\nTotal 0 tests, no errors\n','zero summary'),(b'## recurse\nTotal 7 tests, no errors\nTotal 7 tests, no errors\n','duplicate summary'),(b'Total 7 tests, no errors\n','missing headers')]:
            mutate(unit_paths['testrecurse']/'stdout',body,label,body_rejected('testrecurse'))
        mutate(unit_paths['runsuite']/'stdout',outputs['runsuite'].replace('Total 14','Total 15').encode(),'section total contradiction',body_rejected('runsuite'))
        mutate(raw/'runsuite.log',b'\n------------\nunknown event\n','unknown event',structural_rejection)
        mutate(raw/'runsuite.log',b'','reset/log contradiction',structural_rejection)
        mutate(header,header.read_bytes().replace(b'#if 0',b'#if UNKNOWN'),'unknown preprocessor',structural_rejection)
        mutate(header,header.read_bytes().replace(b'#if 0',b'#if 1'),'feature mismatch',structural_rejection)
        mutate(archive,b'unknown source','unknown effective src',structural_rejection)
        path=unit_paths['testdict'];renamed=commands/'wrong-hash-0';path.rename(renamed);assert inspect()['structuralErrors'];renamed.rename(path);cases.append('hash identity')
        backup=tmp/'unit';shutil.copytree(path,backup);shutil.rmtree(path);assert inspect()['structuralErrors'];shutil.copytree(backup,path);cases.append('missing unit')
        extra=commands/(path.name[:-1]+'1');shutil.copytree(path,extra);assert inspect()['structuralErrors'];shutil.rmtree(extra);cases.append('duplicate counter')
        (raw/'unknown').write_text('');assert inspect()['structuralErrors'];(raw/'unknown').unlink();cases.append('unknown root record')
        log=raw/'runxmlconf.log';log.unlink();assert inspect()['structuralErrors'];log.write_text('');cases.append('missing log')
        original=(path/'stdout').read_bytes();(path/'stdout').unlink();os.link(path/'stderr',path/'stdout');assert inspect()['structuralErrors'];(path/'stdout').unlink();(path/'stdout').write_bytes(original);cases.append('hardlink alias')
        (path/'stdout').unlink();(path/'stdout').symlink_to(path/'stderr');assert inspect()['structuralErrors'];(path/'stdout').unlink();(path/'stdout').write_bytes(original);cases.append('symlink node')
        (path/'stdout').unlink();os.mkfifo(path/'stdout');assert inspect()['structuralErrors'];(path/'stdout').unlink();(path/'stdout').write_bytes(original);cases.append('special node')
        missing_binding=m.inspect(raw,'2.15.3')
        assert not missing_binding['strictPass'] and not missing_binding['units']
        assert any(gap.startswith('SOURCE_FEATURE_BINDING_GAP:') for gap in missing_binding['coverageGaps'])
        cases.append('summary-only binding absent')
        rejects(lambda:m.classify(raw,'2.15.3',contract_file,binding,artifact))
        assert inspect()==baseline
    return {'sourceEntries':68,'inventoryGroups':8,'syntheticOnly':True,'cases':cases,'strictFixturesQualified':0}


if __name__=='__main__':
    print(json.dumps(main(Path(sys.argv[1]).resolve()),indent=2))
