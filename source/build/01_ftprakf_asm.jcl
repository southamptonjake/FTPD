//MAKEFTPD JOB (FTPD),                                                          
//            'Make FTP Daemon',                                                
//            CLASS=A,                                                          
//            MSGCLASS=A,                                                       
//            REGION=8M,                                                        
//            MSGLEVEL=(1,1),                                                   
//            USER=IBMUSER,PASSWORD=SYS1                                        
//*                                                                             
//* First we assemple all the programs as one                                   
//*                                                                             
//FTPLOGIN EXEC ASMFC,PARM.ASM=(OBJ,NODECK),MAC1='SYS2.MACLIB',                 
//         MAC2='SYS1.AMODGEN'                                                  
//ASM.SYSIN DD *                                                                
FTPLOGIN TITLE 'FTP User Login Processor'                                       
***********************************************************************         
***                                                                 ***         
*** Program:  FTPLOGIN                                              ***         
***                                                                 ***         
*** Purpose:  C function to process user login to the FTP service.  ***         
***                                                                 ***         
*** Usage:    unsigned int rac_user_login (char * user, char * pass); *         
***                                                                 ***         
***           where user and pass each point to a null terminated   ***         
***           string of up to eight characters, the username and    ***         
***           the password of the user to be logged in.             ***         
***                                                                 ***         
***           The following return values are defined:              ***         
***                                                                 ***         
***                                return value                     ***         
***           -------------------+--------------                    ***         
***            RAC not available         1                          ***         
***           -------------------+--------------                    ***         
***            login successful     ACEE address                    ***         
***           -------------------+--------------                    ***         
***            login failed              0                          ***         
***                                                                 ***         
*** Function: 1. Check for resource access control (RAC) being      ***         
***              installed and active; always allow login if RAC    ***         
***              is not active.                                     ***         
***                                                                 ***         
***           2. Convert user and pass to RAC format (eight         ***         
***              characters preceeded by a one byte length field).  ***         
***                                                                 ***         
***           3. Authenticate user; don't allow login if            ***         
***              authentication fails.                              ***         
***                                                                 ***         
***           4. Check for authorization to use FTP: If the user    ***         
***              has read access to resource FTPAUTH in class       ***         
***              FACILITY, allow login -- otherwise fail.           ***         
***                                                                 ***         
*** Updates:  2015/03/08 original implementation.                   ***         
***           2015/03/14 return ACEE address.                       ***         
***                                                                 ***         
*** Author:   Juergen Winkelmann, ETH Zuerich.                      ***         
***                                                                 ***         
***********************************************************************         
         PRINT NOGEN            no expansions please                            
FTPLOGIN CSECT ,                start of program                                
         STM   R14,R12,12(R13)  save registers                                  
         L     R2,8(,R13)       \                                               
         LA    R14,96(,R2)       \                                              
         L     R12,0(,R13)        \                                             
         CL    R14,4(,R12)         \                                            
         BL    F1-FTPLOGIN+4(,R15)  \                                           
         L     R10,0(,R12)           \ save area chaining                       
         BALR  R11,R10               / and JCC prologue                         
         CNOP  0,4                  /                                           
F1       DS    0H                  /                                            
         DC    F'96'              /                                             
         STM   R12,R14,0(R2)     /                                              
         LR    R13,R2           /                                               
         LR    R12,R15          establish module addressability                 
         USING FTPLOGIN,R12     tell assembler of base                          
         LR    R11,R1           parameter list                                  
*                                                                               
* verify RAC availability                                                       
*                                                                               
         LA    R7,1             return code if RAC unavailable                  
         L     R1,CVTPTR        get CVT address                                 
         ICM   R1,B'1111',CVTSAF(R1) SAFV defined ?                             
         BZ    LOGNOK           no RAC, allow login                             
         USING SAFV,R1          addressability of SAFV                          
         CLC   SAFVIDEN(4),SAFVID SAFV initialized ?                            
         BNE   LOGNOK           no RAC, allow login                             
         DROP  R1               SAFV no longer needed                           
*                                                                               
* convert C null terminated strings to RAC format                               
*                                                                               
         L     R3,0(,R11)       username address                                
         TRT   0(9,R3),EOS      find end of string                              
         CR    R1,R3            null string?                                    
         BE    LOGNFAIL         yes -> fail                                     
         SR    R1,R3            length of string                                
         STC   R1,USER          store length in RAC username field              
         BCTR  R1,0             decrement for execute                           
         EX    R1,MOVEUSER      get username                                    
         L     R3,4(,R11)       password address                                
         TRT   0(9,R3),EOS      find end of string                              
         CR    R1,R3            null string?                                    
         BE    LOGNFAIL         yes -> fail                                     
         SR    R1,R3            length of string                                
         STC   R1,PASS          store length in RAC password field              
         BCTR  R1,0             decrement for execute                           
         EX    R1,MOVEPASS      get password                                    
         OC    USER+1(8),UPPER  translate username to upper case                
         OC    PASS+1(8),UPPER  translate password to upper case                
*                                                                               
* enter supervisor state                                                        
*                                                                               
         BSPAUTH ON             become authorized                               
         MODESET KEY=ZERO,MODE=SUP enter supervisor state                       
         BSPAUTH OFF            no longer authorized                            
*                                                                               
* authenticate user                                                             
*                                                                               
         RACINIT ENVIR=CREATE,USERID=USER,PASSWRD=PASS,ACEE=ACEE                
         LTR   R5,R15           authentication successful?                      
         BNZ   PROB             no -> return to problem state                   
*                                                                               
* check authorization                                                           
*                                                                               
         LA    R6,0             get PSA address                                 
         USING PSA,R6           tell assembler                                  
         L     R6,PSAAOLD       get ASCB address                                
         USING ASCB,R6          tell assembler                                  
         L     R6,ASCBASXB      get ASXB address                                
         USING ASXB,R6          tell assembler                                  
         L     R7,ASXBSENV      remember ACEE of current user                   
         MVC   ASXBSENV(4),ACEE use ACEE of newly authenticated user            
         RACHECK ENTITY=FTPAUTH,CLASS='FACILITY',ATTR=READ check access         
         LR    R5,R15           remember return code                            
         ST    R7,ASXBSENV      restore ACEE of current user                    
         DROP  R6               ASXB no longer needed                           
         L     R7,ACEE          ACEE of newly logged in user                    
         LTR   R5,R5            authorization ok?                               
         BZ    PROB             yes -> skip logout                              
         RACINIT ENVIR=DELETE,ACEE=ACEE no -> logout                            
*                                                                               
* return to problem state                                                       
*                                                                               
PROB     MODESET KEY=NZERO,MODE=PROB back to problem state                      
         LTR   R5,R5            authentication & authorization ok?              
         BNZ   LOGNFAIL         no -> signal failure                            
LOGNOK   LR    R15,R7           get return code                                 
         B     RETURN           return to caller                                
LOGNFAIL LA    R15,0            return (0);                                     
*                                                                               
* Return to caller                                                              
*                                                                               
RETURN   L     R13,4(,R13)      caller's save area pointer                      
         L     R14,12(,R13)     restore R14                                     
         LM    R1,R12,24(R13)   restore registers                               
         BR    R14              return to caller                                
*                                                                               
* Executed instructions                                                         
*                                                                               
MOVEUSER MVC   USER+1(0),0(R3)  get username                                    
MOVEPASS MVC   PASS+1(0),0(R3)  get password                                    
*                                                                               
* Data area                                                                     
*                                                                               
ACEE     DS    F                ACEE for authentication                         
USER     DS    CL9              username                                        
PASS     DS    CL9              password                                        
UPPER    DC    C'        '      for uppercase translation                       
EOS      DC    X'01',255X'00'   table to find end of string delimiter           
FTPAUTH  DC    CL39'FTPAUTH'    facility name to authorize                      
SAFVID   DC    CL4'SAFV'        SAFV eye catcher                                
         YREGS ,                register equates                                
         CVT   DSECT=YES        map CVT                                         
         IHAPSA ,               map PSA                                         
         IHAASCB ,              map ASCB                                        
         IHAASXB ,              map ASXB                                        
CVTSAF   EQU   248 CVTSAF doesn't exist but is a reserved field in 3.8J         
         ICHSAFV  DSECT=YES     map SAFV                                        
         END   FTPLOGIN         end of FTPLOGIN                                 
/*                                                                              
//ASM.SYSGO DD DSN=&&OBJ,DISP=(,PASS),SPACE=(TRK,3),UNIT=VIO,                   
//        DCB=(RECFM=FB,LRECL=80,BLKSIZE=3200)                                  
//FTPLGOUT EXEC ASMFC,PARM.ASM=(OBJ,NODECK),MAC1='SYS2.MACLIB',                 
//         MAC2='SYS1.AMODGEN'                                                  
//ASM.SYSIN DD *                                                                
FTPLGOUT TITLE 'FTP User Logout Processor'                                      
***********************************************************************         
***                                                                 ***         
*** Program:  FTPLGOUT                                              ***         
***                                                                 ***         
*** Purpose:  C function to process FTP user logout.                ***         
***                                                                 ***         
*** Usage:    unsigned int rac_user_logout (unsigned int acee);     ***         
***                                                                 ***         
***           where acee is the access control environment element  ***         
***           address obtained from rac_user_login when the user    ***         
***           logged in.                                            ***         
***                                                                 ***         
*** Function: Execute RACINIT ENVIR=DELETE to log out the user      ***         
***           identified by acee and return the RACINIT return      ***         
***           code to the caller.                                   ***         
***                                                                 ***         
*** Updates:  2015/03/14 original implementation.                   ***         
***                                                                 ***         
*** Author:   Juergen Winkelmann, ETH Zuerich.                      ***         
***                                                                 ***         
***********************************************************************         
         PRINT NOGEN            no expansions please                            
FTPLGOUT CSECT ,                start of program                                
         STM   R14,R12,12(R13)  save registers                                  
         L     R2,8(,R13)       \                                               
         LA    R14,84(,R2)       \                                              
         L     R12,0(,R13)        \                                             
         CL    R14,4(,R12)         \                                            
         BL    F1-FTPLGOUT+4(,R15)  \                                           
         L     R10,0(,R12)           \ save area chaining                       
         BALR  R11,R10               / and JCC prologue                         
         CNOP  0,4                  /                                           
F1       DS    0H                  /                                            
         DC    F'84'              /                                             
         STM   R12,R14,0(R2)     /                                              
         LR    R13,R2           /                                               
         LR    R12,R15          establish module addressability                 
         USING FTPLGOUT,R12     tell assembler of base                          
         LR    R11,R1           parameter list                                  
*                                                                               
* enter supervisor state                                                        
*                                                                               
         BSPAUTH ON             become authorized                               
         MODESET KEY=ZERO,MODE=SUP enter supervisor state                       
         BSPAUTH OFF            no longer authorized                            
*                                                                               
* log out                                                                       
*                                                                               
         L     R3,0(,R11)       ACEE address                                    
         RACINIT ENVIR=DELETE,ACEE=(3) logout                                   
         LR    R5,R15           remember return code                            
*                                                                               
* return to problem state                                                       
*                                                                               
         MODESET KEY=NZERO,MODE=PROB back to problem state                      
*                                                                               
* Return to caller                                                              
*                                                                               
         LR    R15,R5           get RACINIT return code                         
         L     R13,4(,R13)      caller's save area pointer                      
         L     R14,12(,R13)     restore R14                                     
         LM    R1,R12,24(R13)   restore registers                               
         BR    R14              return to caller                                
*                                                                               
* Data area                                                                     
*                                                                               
         YREGS ,                register equates                                
         END   FTPLGOUT         end of FTPLGOUT                                 
/*                                                                              
//ASM.SYSGO DD DSN=&&OBJ,DISP=(MOD,PASS)                                        
//FTPAUTH  EXEC ASMFC,PARM.ASM=(OBJ,NODECK),MAC1='SYS2.MACLIB',                 
//         MAC2='SYS1.AMODGEN'                                                  
//ASM.SYSIN DD *                                                                
FTPAUTH  TITLE 'FTP Authorization Processor'                                    
***********************************************************************         
***                                                                 ***         
*** Program:  FTPAUTH                                               ***         
***                                                                 ***         
*** Purpose:  C function to authorize or unauthorize FTPD.          ***         
***                                                                 ***         
*** Usage:    void rac_ftpd_auth (unsigned int state);              ***         
***                                                                 ***         
*** Function: Use SVC244 to set or clear JSCBAUTH, depending on     ***         
***           the value (0/1) of state.                             ***         
***                                                                 ***         
*** Updates:  2015/03/15 original implementation.                   ***         
***                                                                 ***         
*** Author:   Juergen Winkelmann, ETH Zuerich.                      ***         
***                                                                 ***         
***********************************************************************         
         PRINT NOGEN            no expansions please                            
FTPAUTH  CSECT ,                start of program                                
         STM   R14,R12,12(R13)  save registers                                  
         L     R2,8(,R13)       \                                               
         LA    R14,84(,R2)       \                                              
         L     R12,0(,R13)        \                                             
         CL    R14,4(,R12)         \                                            
         BL    F1-FTPAUTH+4(,R15)   \                                           
         L     R10,0(,R12)           \ save area chaining                       
         BALR  R11,R10               / and JCC prologue                         
         CNOP  0,4                  /                                           
F1       DS    0H                  /                                            
         DC    F'84'              /                                             
         STM   R12,R14,0(R2)     /                                              
         LR    R13,R2           /                                               
         LR    R12,R15          establish module addressability                 
         USING FTPAUTH,R12      tell assembler of base                          
         LR    R11,R1           parameter list                                  
*                                                                               
* set or clear?                                                                 
*                                                                               
         L     R3,0(,R11)       state ..                                        
         LTR   R3,R3              .. = 0?                                       
         BZ    CLEAR            yes -> clear                                    
*                                                                               
* set JSCBAUTH                                                                  
*                                                                               
         BSPAUTH ON             become authorized                               
         B     RETURN           return                                          
*                                                                               
* clear JSCBAUTH                                                                
*                                                                               
CLEAR    BSPAUTH OFF            no longer authorized                            
*                                                                               
* Return to caller                                                              
*                                                                               
RETURN   L     R13,4(,R13)      caller's save area pointer                      
         L     R14,12(,R13)     restore R14                                     
         LM    R1,R12,24(R13)   restore registers                               
         BR    R14              return to caller                                
*                                                                               
* Data area                                                                     
*                                                                               
         YREGS ,                register equates                                
         END   FTPAUTH          end of FTPAUTH                                  
/*                                                                              
//ASM.SYSGO DD DSN=&&OBJ,DISP=(MOD,PASS)                                        
//FTPSU    EXEC ASMFC,PARM.ASM=(OBJ,NODECK),MAC1='SYS2.MACLIB',                 
//         MAC2='SYS1.AMODGEN'                                                  
//ASM.SYSIN DD *                                                                
FTPSU    TITLE 'FTP Switch User Processor'                                      
***********************************************************************         
***                                                                 ***         
*** Program:  FTPSU                                                 ***         
***                                                                 ***         
*** Purpose:  C function to switch user                             ***         
***                                                                 ***         
*** Usage:    unsigned int rac_switch_user (unsigned int acee);     ***         
***                                                                 ***         
***           where acee is the access control environment element  ***         
***           address obtained from rac_user_login when the user    ***         
***           logged in.                                            ***         
***                                                                 ***         
*** Function: Replace the contents of ASXBSENV with acee and return ***         
***           the previous ASXBENV contents to the caller.          ***         
***                                                                 ***         
*** Updates:  2015/03/15 original implementation.                   ***         
***                                                                 ***         
*** Author:   Juergen Winkelmann, ETH Zuerich.                      ***         
***                                                                 ***         
***********************************************************************         
         PRINT NOGEN            no expansions please                            
FTPSU    CSECT ,                start of program                                
         STM   R14,R12,12(R13)  save registers                                  
         L     R2,8(,R13)       \                                               
         LA    R14,96(,R2)       \                                              
         L     R12,0(,R13)        \                                             
         CL    R14,4(,R12)         \                                            
         BL    F1-FTPSU+4(,R15)     \                                           
         L     R10,0(,R12)           \ save area chaining                       
         BALR  R11,R10               / and JCC prologue                         
         CNOP  0,4                  /                                           
F1       DS    0H                  /                                            
         DC    F'96'              /                                             
         STM   R12,R14,0(R2)     /                                              
         LR    R13,R2           /                                               
         LR    R12,R15          establish module addressability                 
         USING FTPSU,R12        tell assembler of base                          
         LR    R11,R1           parameter list                                  
*                                                                               
* enter supervisor state                                                        
*                                                                               
         MODESET KEY=ZERO,MODE=SUP enter supervisor state                       
*                                                                               
* switch user                                                                   
*                                                                               
         LA    R6,0             get PSA address                                 
         USING PSA,R6           tell assembler                                  
         L     R6,PSAAOLD       get ASCB address                                
         USING ASCB,R6          tell assembler                                  
         L     R6,ASCBASXB      get ASXB address                                
         USING ASXB,R6          tell assembler                                  
         L     R7,ASXBSENV      remember ACEE address of current user           
         L     R3,0(,R11)       ACEE address of new user                        
         ST    R3,ASXBSENV      switch to new user                              
         DROP  R6               ASXB no longer needed                           
*                                                                               
* return to problem state                                                       
*                                                                               
         MODESET KEY=NZERO,MODE=PROB back to problem state                      
         LR    R15,R7           return ACEE adress of previous user             
*                                                                               
* Return to caller                                                              
*                                                                               
RETURN   L     R13,4(,R13)      caller's save area pointer                      
         L     R14,12(,R13)     restore R14                                     
         LM    R1,R12,24(R13)   restore registers                               
         BR    R14              return to caller                                
*                                                                               
* Data area                                                                     
*                                                                               
         YREGS ,                register equates                                
         IHAPSA ,               map PSA                                         
         IHAASCB ,              map ASCB                                        
         IHAASXB ,              map ASXB                                        
         END   FTPSU            end of FTPSU                                    
/*                                                                              
//ASM.SYSGO DD DSN=&&OBJ,DISP=(MOD,PASS)                                        
//* Now to output the temp dataset &&OBJ to Class B which is the                
//* punch out (pch00d.txt or changed to ftpdrakf.punch using)                   
//PUNCHOUT EXEC PGM=IEBGENER                                                    
//SYSIN    DD DUMMY                                                             
//SYSUT1   DD DSN=&&OBJ,DISP=SHR                                                
//SYSUT2   DD SYSOUT=B                                                          
//SYSPRINT DD SYSOUT=*                                                          
