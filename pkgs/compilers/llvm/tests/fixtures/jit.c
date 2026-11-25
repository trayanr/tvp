#include <llvm-c/Core.h>
#include <llvm-c/Error.h>
#include <llvm-c/Target.h>
#if TVP_ORC_API == 1
#include <llvm-c/OrcBindings.h>
#include <llvm-c/TargetMachine.h>
#else
#include <llvm-c/LLJIT.h>
#endif
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static void check_error(LLVMErrorRef error)
{
  if (error) {
    char *message = LLVMGetErrorMessage(error);
    fputs(message, stderr);
    LLVMDisposeErrorMessage(message);
    exit(1);
  }
}

static LLVMModuleRef answer_module(LLVMContextRef context)
{
  LLVMModuleRef module = LLVMModuleCreateWithNameInContext("tvp", context);
  LLVMTypeRef integer = LLVMInt32TypeInContext(context);
  LLVMTypeRef signature = LLVMFunctionType(integer, NULL, 0, 0);
  LLVMValueRef answer = LLVMAddFunction(module, "tvp_answer", signature);
  LLVMBasicBlockRef entry = LLVMAppendBasicBlockInContext(context, answer, "entry");
  LLVMBuilderRef builder = LLVMCreateBuilderInContext(context);

  LLVMPositionBuilderAtEnd(builder, entry);
  LLVMBuildRet(builder, LLVMConstInt(integer, 42, 0));
  LLVMDisposeBuilder(builder);
  return module;
}

#if TVP_ORC_API == 1
static uint64_t resolve_symbol(const char *name, void *context)
{
  (void) name;
  (void) context;
  return 0;
}
#endif

int main(void)
{
  if (LLVMInitializeNativeTarget() || LLVMInitializeNativeAsmPrinter())
    return 1;

#if TVP_ORC_API == 1
  char *triple = LLVMGetDefaultTargetTriple();
  LLVMTargetRef target;
  char *message;
  if (LLVMGetTargetFromTriple(triple, &target, &message)) {
    fputs(message, stderr);
    LLVMDisposeMessage(message);
    LLVMDisposeMessage(triple);
    return 1;
  }

  LLVMTargetMachineRef machine = LLVMCreateTargetMachine(
      target, triple, "generic", "", LLVMCodeGenLevelDefault, LLVMRelocDefault,
      LLVMCodeModelJITDefault);
  if (!machine) {
    LLVMDisposeMessage(triple);
    return 1;
  }

  LLVMContextRef context = LLVMContextCreate();
  LLVMModuleRef module = answer_module(context);
  LLVMTargetDataRef layout = LLVMCreateTargetDataLayout(machine);
  LLVMSetTarget(module, triple);
  LLVMSetModuleDataLayout(module, layout);
  LLVMDisposeTargetData(layout);
  LLVMDisposeMessage(triple);

  LLVMOrcJITStackRef jit = LLVMOrcCreateInstance(machine);
  LLVMOrcModuleHandle handle;
  LLVMOrcTargetAddress address;
  check_error(LLVMOrcAddEagerlyCompiledIR(jit, &handle, module,
                                         resolve_symbol, NULL));
  check_error(LLVMOrcGetSymbolAddress(jit, &address, "tvp_answer"));
#else
  LLVMOrcLLJITRef jit;
  LLVMOrcExecutorAddress address;
  check_error(LLVMOrcCreateLLJIT(&jit, NULL));

  LLVMOrcThreadSafeContextRef context = LLVMOrcCreateNewThreadSafeContext();
  LLVMModuleRef module = answer_module(LLVMOrcThreadSafeContextGetContext(context));
  LLVMSetTarget(module, LLVMOrcLLJITGetTripleString(jit));
  LLVMSetDataLayout(module, LLVMOrcLLJITGetDataLayoutStr(jit));
  LLVMOrcThreadSafeModuleRef wrapped = LLVMOrcCreateNewThreadSafeModule(module, context);
  check_error(LLVMOrcLLJITAddLLVMIRModule(jit, LLVMOrcLLJITGetMainJITDylib(jit), wrapped));
  LLVMOrcDisposeThreadSafeContext(context);
  check_error(LLVMOrcLLJITLookup(jit, &address, "tvp_answer"));
#endif

  int answer = address ? ((int (*)(void)) (uintptr_t) address)() : 0;
#if TVP_ORC_API == 1
  check_error(LLVMOrcDisposeInstance(jit));
  LLVMContextDispose(context);
#else
  check_error(LLVMOrcDisposeLLJIT(jit));
#endif
  if (answer != 42)
    return 1;
  printf("%d\n", answer);
  return 0;
}
