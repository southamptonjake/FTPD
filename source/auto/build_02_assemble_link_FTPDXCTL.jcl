//FTPDXCTL JOB  (FTPD),
//             'Make FTPDXCTL',
//             CLASS=A,
//             MSGCLASS=A,
//             REGION=8192K,
//             USER=IBMUSER,PASSWORD=SYS1,
//             MSGLEVEL=(1,1)
//*********************************************************************
//*
//* Desc: Assemble and link FTPD Wrapper
//*
//* Places FTPDXCTL in SYS2.LINKLIB
//* Requires SYS2.MACLIB be installed
//*
//*********************************************************************
//*
//ASMCL   EXEC ASMFCL,PARM.ASM=(OBJ,NODECK,NOXREF),
//        MAC='SYS1.AMODGEN',MAC1='SYS2.MACLIB'
//ASM.SYSIN DD *
FTPDXCTL TITLE 'Set user and group for FTPD started task'
***********************************************************************
***                                                                 ***
*** Program:  FTPDXCTL                                              ***
***                                                                 ***
*** Purpose:  Wrapper for FTPD started task to run                  ***
***           using user/group FTPD/USER instead of STC/STCGROUP    ***
***                                                                 ***
*** Usage:    Replace FTPD in PGM parameter of EXEC statement with  ***
***           FTPDXCTL.                                             ***
***                                                                 ***
*** Function: 1. Enter supervisor state.                            ***
***                                                                 ***
***           2. Delete current security environment.               ***
***                                                                 ***
***           3. Create new security environment using FTPD/USER.   ***
***                                                                 ***
***           4. Return to problem state.                           ***
***                                                                 ***
***           5. Pass control to FTPD via XCTL.                     ***
***                                                                 ***
*** Updates:  2015/03/03 original implementation.                   ***
***                                                                 ***
*** Author:   Juergen Winkelmann, ETH Zuerich.                      ***
***                                                                 ***
***********************************************************************
         PRINT NOGEN            no expansions please
FTPDXCTL CSECT ,                start of program
         SAVE  (14,12),,*       save registers
         LR    R12,R15          establish module addressability
         USING FTPDXCTL,R12     tell assembler of base
         LA    R2,SAVEA         chain ..
         ST    R13,4(,R2)         .. the ..
         ST    R2,8(,R13)           .. save ..
         LR    R13,R2                 .. areas
*
* Enter supervisor state
*
         BSPAUTH ON             become authorized
         MODESET KEY=ZERO,MODE=SUP enter supervisor state
         BSPAUTH OFF            no longer authorized
*
* switch to user FTPD and group USER
*
         RACINIT ENVIR=DELETE   delete and recreate RAC environment
         RACINIT ENVIR=CREATE,USERID=FTPD,GROUP=USER,PASSCHK=NO
*
* Return to problem state
*
         MODESET KEY=NZERO,MODE=PROB back to problem state
*
* Pass control to FTPD
*
         L     R13,4(,R13)      caller's save area pointer
         L     R1,24(,R13)      parameter list for FTPD
         XCTL  (2,12),EP=FTPD   execute FTPD, return never
*
* Data area
*
SAVEA    DS    18F              save area
FTPD     DC    X'04',C'FTPD'    new user
USER     DC    X'04',C'USER'    new group
         YREGS ,                register equates
         END   FTPDXCTL         end of FTPDXCTL
//LKED.SYSLMOD DD DSN=SYS2.LINKLIB(FTPDXCTL),DISP=SHR