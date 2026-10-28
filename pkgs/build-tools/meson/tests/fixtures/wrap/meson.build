project('wrap-archive', 'c')
child = dependency('child', fallback: ['child', 'child_dep'])
answer = executable('answer', 'main.c', dependencies: child)
test('answer', answer)
