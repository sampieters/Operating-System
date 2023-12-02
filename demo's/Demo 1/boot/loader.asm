[BITS 16]
[ORG 0x7e00]

mov [DriveId], dl                                            ; before we jumped to the loader, we set the drive id in dl.

; -----------------------------------------------------
; Check if CPUID is supported by attempting to flip the ID bit (bit 21) in the FLAGS register. If we can flip it, CPUID is available.
; -----------------------------------------------------
pushfd                                                      ; Copy FLAGS in to EAX via stack
pop eax
mov ecx, eax                                                ; Copy to ECX as well for comparing later on
xor eax, 1 << 21                                            ; Flip the ID bit
push eax                                                    ; Copy EAX to FLAGS via the stack
popfd
pushfd                                                      ; Copy FLAGS back to EAX (with the flipped bit if CPUID is supported)
pop eax
push ecx                                                    ; Restore FLAGS from the old version stored in ECX (i.e. flipping the ID bit back if it was ever flipped).
popfd
cmp eax, ecx                                                ; Compare EAX and ECX. If they are equal then that means the bit wasn't flipped, and CPUID isn't supported.
je NotSupported

; -----------------------------------------------------
; check if cpu supports long mode
; -----------------------------------------------------
mov	eax, 0x80000000
cpuid
cmp	eax, 0x80000001											; check if the return value in eax is less than 0x80000001. If it is then the input value 0x80000001 is not supported.
jb	NotSupported

mov eax, 0x80000001											; this value will return processor features, a different value will return different information of the cpuid.
cpuid														; cpuid is an instruction which returns the processor identification and feature information.
test edx, (1<<29)											; the information about long mode is saved in edx on bit 29. If it is set, long mode is supported.
jz	NotSupported

; -----------------------------------------------------
; check if cpu supports 1G page support
; -----------------------------------------------------
; Load the kernel
; test edx, (1<<26)											; check 1G page support which is saved in edx on bit 26.
; jz	NotSupported
; -----------------------------------------------------

; -----------------------------------------------------
; Load the kernel
; -----------------------------------------------------
mov si, ReadPacket                                          ; define a structure.
mov word[si], 0x10                                          ; the first word holds the value of the structure lenght which is 16 bytes (or 0x10 in hexadecimal).
mov word[si+2], 100                                         ; the second word holds the number of sectors we want to read, 100 sector or roughly 50 kB is enough for the kernel.
mov word[si+4], 0	                                        ; the third word is the offset.
mov word[si+6], 0x1000                                      ; the fourth word is the segment. The loader starts at address 0x7e00.
mov dword[si+8], 6
mov dword[si+0xc], 0
mov dl, [DriveId]                                           
mov ah, 0x42
int 0x13
jc	ReadError

LoadUser:
    mov si,ReadPacket
    mov word[si],0x10
    mov word[si+2],10
    mov word[si+4],0
    mov word[si+6],0x2000
    mov dword[si+8],106
    mov dword[si+0xc],0
    mov dl,[DriveId]
    mov ah,0x42
    int 0x13
    jc  ReadError

LoadUser2:
    mov si,ReadPacket
    mov word[si],0x10
    mov word[si+2],10
    mov word[si+4],0
    mov word[si+6],0x3000
    mov dword[si+8],116
    mov dword[si+0xc],0
    mov dl,[DriveId]
    mov ah,0x42
    int 0x13
    jc  ReadError

LoadUser3:
    mov si,ReadPacket
    mov word[si],0x10
    mov word[si+2],10
    mov word[si+4],0
    mov word[si+6],0x4000
    mov dword[si+8],126
    mov dword[si+0xc],0
    mov dl,[DriveId]
    mov ah,0x42
    int 0x13
    jc  ReadError

; -----------------------------------------------------
; Get memory info when we start the loader
; -----------------------------------------------------
mov eax,0xe820
mov edx,0x534d4150
mov ecx,20
mov dword[0x9000],0
mov edi,0x9008
xor ebx,ebx
int 0x15
jc NotSupported

GetMemInfo:
    add edi,20
    inc dword[0x9000]   
    test ebx,ebx
    jz GetMemDone

    mov eax,0xe820
    mov edx,0x534d4150
    mov ecx,20
    int 0x15
    jnc GetMemInfo

GetMemDone:
; -----------------------------------------------------
; Test the A20 line
; -----------------------------------------------------
    mov ax,0xffff
    mov es,ax
    mov word[ds:0x7c00],0xa200
    cmp word[es:0x7c10],0xa200
    jne SetA20LineDone
    mov word[0x7c00],0xb200
    cmp word[es:0x7c10],0xb200
    je End
    
SetA20LineDone:
    xor ax,ax
    mov es,ax

SetVideoMode:
    mov ax,3
    int 0x10

; -----------------------------------------------------
; Prepare to go to protected mode
; -----------------------------------------------------
    cli
    lgdt [Gdt32Ptr]
    lidt [Idt32Ptr]

    mov eax,cr0
    or eax,1
    mov cr0,eax

    jmp 8:PMEntry

ReadError:
NotSupported:
End:
    hlt
    jmp End


[BITS 32]
PMEntry:
    mov ax,0x10
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov esp,0x7c00

    cld
    mov edi,0x70000
    xor eax,eax
    mov ecx,0x10000/4
    rep stosd
    
    mov dword[0x70000],0x71003
    mov dword[0x71000],10000011b

    mov eax,(0xffff800000000000>>39)
    and eax,0x1ff
    mov dword[0x70000+eax*8],0x72003
    mov dword[0x72000],10000011b

    lgdt [Gdt64Ptr]

    mov eax,cr4
    or eax,(1<<5)
    mov cr4,eax

    mov eax,0x70000
    mov cr3,eax

    mov ecx,0xc0000080
    rdmsr
    or eax,(1<<8)
    wrmsr

    mov eax,cr0
    or eax,(1<<31)
    mov cr0,eax

    jmp 8:LMEntry

PEnd:
    hlt
    jmp PEnd

[BITS 64]
LMEntry:
    mov rsp,0x7c00

    cld
    mov rdi,0x200000
    mov rsi,0x10000
    mov rcx,51200/8
    rep movsq

    mov rax,0xffff800000200000
    jmp rax
    
LEnd:
    hlt
    jmp LEnd
    
    

DriveId:    db 0
ReadPacket: times 16 db 0

Gdt32:
    dq 0
Code32:
    dw 0xffff
    dw 0
    db 0
    db 0x9a
    db 0xcf
    db 0
Data32:
    dw 0xffff
    dw 0
    db 0
    db 0x92
    db 0xcf
    db 0
    
Gdt32Len: equ $-Gdt32

Gdt32Ptr: dw Gdt32Len-1
          dd Gdt32

Idt32Ptr: dw 0
          dd 0


Gdt64:
    dq 0
    dq 0x0020980000000000

Gdt64Len: equ $-Gdt64


Gdt64Ptr: dw Gdt64Len-1
          dd Gdt64
