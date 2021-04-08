	.file	"asm_test.c"
	.text
	.globl	count
	.data
	.align 4
	.type	count, @object
	.size	count, 4
count:
	.long	1
	.globl	value
	.align 4
	.type	value, @object
	.size	value, 4
value:
	.long	1
	.comm	buf,40,32
	.text
	.globl	main
	.type	main, @function
main:
.LFB0:
	.cfi_startproc
	endbr64
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register 6
	movl	count(%rip), %edx
	movl	value(%rip), %eax
	leaq	buf(%rip), %rsi
	movl	%edx, %ecx
	movq	%rsi, %rdi
#APP
# 6 "asm_test.c" 1
	cld 
	rep 
	stosl
# 0 "" 2
#NO_APP
	nop
	popq	%rbp
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE0:
	.size	main, .-main
	.ident	"GCC: (Ubuntu 9.3.0-17ubuntu1~20.04) 9.3.0"
	.section	.note.GNU-stack,"",@progbits
	.section	.note.gnu.property,"a"
	.align 8
	.long	 1f - 0f
	.long	 4f - 1f
	.long	 5
0:
	.string	 "GNU"
1:
	.align 8
	.long	 0xc0000002
	.long	 3f - 2f
2:
	.long	 0x3
3:
	.align 8
4:
