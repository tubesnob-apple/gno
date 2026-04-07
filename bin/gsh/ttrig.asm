         mcopy ttrig.mac
TEST     START
p        equ   0
arg      equ   p+4
space    equ   arg+4
         subroutine (2:argc,4:argv),space
         RTS
         END
