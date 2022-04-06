; A zip/gzip chimera with any file deflated
; AKA a zip/gzip polyglot where the deflate archived file content is shared

; Generate with nasm/yasm: nasm -o archive.zip.gz zgip.asm

; Optionally, some deflate blocks can be skipped by Gzip extra field.
; To make Zip ignore some data, store it in extra members in between Zip structures.

; Just to prove that while Zip and Gzip can use the same compression algorithm,
;   neither is an encapsulation of the other.

; Ange Albertini MIT 2022


%include "zip.inc"
%include "gzip.inc"

; Generated by make.py
%include "external.inc"

;  GZIP           ZIP
; header 1
; [extrafield]
;                LFH (w CRC + sizes)
;                filename
; [filename0]
;                [extrafield]
; [comment0]
; body
;                body
; crc
; size

; header 2
; [extrafield]
;                CD (w/ CRC + sizes)
;                filename
;                extra field
;                comment
; body


%macro _zfilename 0
  db 'zipped.txt'
%endmacro


; No gzip filename is possible
;   if the Extra Field is used to skip Deflate blocks
%if SKIP == 0
  GZFN equ b_flg.fname
  %macro _gzfilename 0
    db 'gzipped.txt'
    ; in gzip, it's just a null-terminated string !
    db 0
  %endmacro
%else
  GZFN equ 0
  %macro _gzfilename 0
  %endmacro
%endif

gzip.sig db 0x1f, 0x8b
gzip.CompressionMethod db e_deflate
gzip.Flags db b_flg.fextra + GZFN
gzip.Mtime dd 0
gzip.eXtraFields db b_xfl.max
gzip.Os db b_os.unknown

  dw gzip.EXTRAFIELD_L
gzip.Extrafield:
  gzip.Subfield.id db 'GZ'
  gzip.Subfield.length dw gzip.SUBFIELD.LENGTH
  gzip.Subfield.data:
                                                        lfh:
                                                        istruc filerecord
                                                          at filerecord.frSignature,        db "PK", 3, 4
                                                          at filerecord.frVersion,          dw 0ah
                                                          at filerecord.frCompression,      dw COMP_DEFLATE
                                                          at filerecord.frCrc,              dd EXT_ZCRC32
                                                          at filerecord.frCompressedSize,   dd lfh.DATA_SIZE
                                                          at filerecord.frUncompressedSize, dd EXT_USIZE
                                                          at filerecord.frFileNameLength,   dw zip.FILENAME_LEN
                                                          at filerecord.frExtraFieldLength, dw lfh.EXTRAFIELD_LEN
                                                        iend
                                                        zip.filename:
                                                          _zfilename
                                                        zip.FILENAME_LEN equ $ - zip.filename

                                                        lfh.extrafield:
                                                        db "ZI"
                                                        dw lfh.EXTRAFIELD_LEN - 4
    gzip.SUBFIELD.LENGTH equ SKIP + $ - gzip.Subfield.data
gzip.EXTRAFIELD_L equ SKIP + $ - gzip.Extrafield

; Gzipped filename
_gzfilename
                                                           lfh.EXTRAFIELD_LEN equ $ - lfh.extrafield
                                                        lfh.data:

                                                  EXT_DATA

                                                        lfh.DATA_SIZE equ $ - lfh.data
dd EXT_GZCRC32
dd EXT_GSIZE

; 2nd member to hide the rest of the zip - required for python gzip
db 0x1f, 0x8b
db e_deflate
db b_flg.fextra
dd 0
db b_xfl.max
db b_os.unknown
  dw gzip2.EXTRAFIELD_L1
gzip2.Extrafield:
  gzip2.Subfield.id db 'GZ'
  gzip2.Subfield.length dw gzip2.SUBFIELD.LENGTH
  gzip2.Subfield.data:
                                                        central_directory:
                                                        istruc direntry
                                                          at direntry.deSignature,        db "PK", 1, 2
                                                          at direntry.deVersionToExtract, dw 0ah
                                                          at direntry.deCompression,      dw COMP_DEFLATE ; required for python zipfile
                                                          at direntry.deCrc,              dd EXT_ZCRC32
                                                          at direntry.deCompressedSize,   dd lfh.DATA_SIZE
                                                          at direntry.deUncompressedSize, dd EXT_USIZE
                                                          at direntry.deFileNameLength,   dw .FILENAME_LEN
                                                          at direntry.deHeaderOffset,     dd lfh
                                                        iend
                                                        .filename:
                                                          _zfilename
                                                        .FILENAME_LEN equ $ - .filename

                                                        CENTRAL_DIRECTORY_SIZE equ $ - central_directory

                                                        EoCD:
                                                        istruc endlocator
                                                          at endlocator.elSignature,          db "PK", 5, 6
                                                          at endlocator.elEntriesInDirectory, db 1
                                                          at endlocator.elDirectorySize,      dd CENTRAL_DIRECTORY_SIZE
                                                          at endlocator.elDirectoryOffset,    dd central_directory
                                                          at endlocator.elCommentLength,      dw .COMMENT_LEN
                                                        iend
                                                        .comment:
                                                          db 0 ; to prevent comment display
  gzip2.SUBFIELD.LENGTH equ $ - gzip2.Subfield.data
gzip2.EXTRAFIELD_L1 equ $ - gzip2.Extrafield
db 3, 0
dd 0
dd 0
                                                        .COMMENT_LEN equ $ - .comment
