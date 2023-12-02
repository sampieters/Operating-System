; ----------------------------------------------------
; directive bits
; ----------------------------------------------------
[BITS 16]                   ; This tells that the code is running in real mode (= bits)       
[ORG 0x7c00]                ; The code is supposed to be running at memory address 0x7c00

; this is the beginning of the code, normally this is labeled start but because it is on top of the code it doesn't matter.
; We initialise the stack here. The boot code starts at 0x7c00 and the stack is set up below 0x7c00.
; The stack grows downwards.
xor ax,ax                                                   ; The xor makes the value in ax zero
mov ds,ax                                                   ; we move zero in ds, es and ss, this we do because when we memory address these later in our code ze don't have to worry about the values in them.
mov es,ax  
mov ss,ax
mov sp,0x7c00                                               ; We assign 0x7c00 to the stack pointer register (= sp).

; -----------------------------------------------------
; Test the disk extension, also no label required
; -----------------------------------------------------
mov [DriveId], dl                                           ; dl holds the drive id when BIOS transfer control to boot code.
mov ah,0x41
mov bx, 0x55aa
int 0x13                                                    ; drive test call, if the service is not supported the carry flag is set.
jc  NotSupported                                            ; jc instruction jumps to label if carry flag is set.
cmp bx, 0xaa55
jne NotSupported

LoadLoader:
    mov si,ReadPacket
    mov word[si],0x10
    mov word[si+2],5
    mov word[si+4],0x7e00
    mov word[si+6],0
    mov dword[si+8],1
    mov dword[si+0xc],0
    mov dl,[DriveId]
    mov ah,0x42
    int 0x13
    jc  ReadError

    mov dl,[DriveId]
    jmp 0x7e00 

; -----------------------------------------------------
; Error handling if the test of the disk extension failed.
; -----------------------------------------------------
ReadError:
NotSupported:
    mov ah,0x13                                                 ; ah holds the function code (0x13: print string).
    mov al,1                                                    ; parameter al specifies the write mode (set to 1 means that the cursor will be placed at the end of the string)
    mov bx,0xa                                                  ; We save the color code for green in bx. This is the color of the text.
    xor dx,dx                                                   ; Dh is the higher part of dx register qnd represent the rows and dl is the lower part of dx and represent the columns. set to zero because we want to write at the beginning of our terminal.
    mov bp,Message                                              ; Bp holds the address of the string we want to print.
    mov cx,MessageLen                                           ; Cx specifies the number of characters to print.
    int 0x10                                                    ; call BIOS services with a BIOS interrupt


End:
    hlt                                                         ; hlt instruction places the processor in a halt state.
    jmp End                                                     ; infinite loop
    
DriveId:    db 0
Message:    db "We have an error in boot process"
MessageLen: equ $-Message
ReadPacket: times 16 db 0

times (0x1be-($-$$)) db 0                                   ; '(0x1be-($-$$))' is the amount of times that db has to be repeated. $$ = beginning of the current section.

    db 80h                                                  ; boot partion, 80h means that this partision is bootable.
    db 0,2,0                                                ; c,h,s = 0,2,0 where c = cylinder, h = head and s = sector.
    db 0f0h
    db 0ffh,0ffh,0ffh                                       ; ending c,h,s all set to FF which is the max value that can be set in a byte.
    dd 1                                                    ; starting sector
    dd (20*16*63-1)
	
    times (16*3) db 0

    db 0x55                                                 ; last two bytes 55AA is the signature of the boot file.
    db 0xaa