.section .rodata
message: .ascii "tvp"
.section .text
.global _start
_start:
    mov $1, %rax
    mov $1, %rdi
    lea message(%rip), %rsi
    mov $3, %rdx
    syscall
    mov $60, %rax
    xor %rdi, %rdi
    syscall
.section .note.GNU-stack,"",@progbits
