       CBL APOST
      *----------------------------------------------------------------*
      *                                                                *
      * ENTRY POINT = GETAPI                                           *
      *                                                                *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. GETAPI.
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *----------------------------------------------------------------*
      * Common defintions                                              *
      *----------------------------------------------------------------*
       01  functionCode PIC 9(9) BINARY.
       01  envVariableNameLength PIC 9(9) BINARY.
       01  envVariableName PIC X(255).
       01  valueLength PIC 9(9) BINARY.
       01  valuePointer POINTER.
       01  ws-length PIC 9(3).

       01  feedbackCode.
           02  CONDITION-TOKEN-VALUE.
           COPY  CEEIGZCT.
               03  CASE-1-CONDITION-ID.
                  04  SEVERITY     PIC S9(4) BINARY.
                  04  MSG-NO       PIC S9(4) BINARY.
               03  CASE-SEV-CTL    PIC X.
               03  FACILITY-ID     PIC XXX.
           02  I-S-INFO            PIC S9(9) BINARY.
       01  VAL       PIC X(255).

      * Error Message structure
       01  ERROR-MSG.
           03 EM-ORIGIN                PIC X(8)  VALUE SPACES.
           03 EM-CODE                  PIC S9(9) COMP-5 SYNC VALUE 0.
           03 EM-DETAIL                PIC X(1024) VALUE SPACES.

      * Copy API Requester required copybook
       COPY BAQRINFO.

      * Request and Response
       01 GET-REQUEST.
           COPY CSC00Q01.
       01 GET-RESPONSE.
           COPY CSC00P01.
      * Structure with the API information
       01 GET-INFO-OPER1.
           COPY CSC00I01.

      * Request and Response segment, used to store request and
      * response content.
       01 BAQ-REQUEST-PTR             USAGE POINTER.
       01 BAQ-REQUEST-LEN             PIC S9(9) COMP-5 SYNC.
       01 BAQ-RESPONSE-PTR            USAGE POINTER.
       01 BAQ-RESPONSE-LEN            PIC S9(9) COMP-5 SYNC.
       01 EIBRESP                     PIC X(8).
       01 EIBRESP2                    PIC X(8).
       77 COMM-STUB-PGM-NAME          PIC X(8) VALUE 'BAQCSTUB'.

      *----------------------------------------------------------------*

      ******************************************************************
      *    L I N K A G E   S E C T I O N
      ******************************************************************
       LINKAGE SECTION.
       01   PARM-BUFFER.
            05 PARM-LENGTH   PIC S9(4) COMP.
            05 PARM-DATA.
               10 employee   PIC X(6).
               10 filler     PIC X(250).
      ******************************************************************
      *    P R O C E D U R E S
      ******************************************************************
       PROCEDURE DIVISION using PARM-BUFFER.

      *----------------------------------------------------------------*
       MAINLINE SECTION.

      *----------------------------------------------------------------*
      * Common code                                                    *
      *----------------------------------------------------------------*
      * initialize working storage variables
           INITIALIZE GET-REQUEST.
           INITIALIZE GET-RESPONSE.

      *****************************************************
      **   Set the BAQURI and BAQPORT environment variables
      *****************************************************
           MOVE "BAQURI" TO envVariableName.
           MOVE 6 TO envVariableNameLength.
           MOVE "wg31.washington.ibm.com" TO VAL.
           MOVE 23 TO valueLength.
           PERFORM CALL-CEEENV THRU CALL-CEEENV-END
           MOVE "BAQPORT" TO envVariableName.
           MOVE 7 TO envVariableNameLength.
           MOVE "9120" TO VAL.
           MOVE 4 TO valueLength.
           PERFORM CALL-CEEENV THRU CALL-CEEENV-END

      *---------------------------------------------------------------*
      * Set up the data for the API Requester call                    *
      *---------------------------------------------------------------*
           MOVE employee of PARM-DATA TO employee IN GET-REQUEST.
           MOVE LENGTH of employee in GET-REQUEST to
               employee-length IN GET-REQUEST.

      *---------------------------------------------------------------*
      * Initialize API Requester PTRs & LENs                          *
      *---------------------------------------------------------------*
      * Use pointer and length to specify the location of
      *  request and response segment.
      * This procedure is general and necessary.
           SET BAQ-REQUEST-PTR TO ADDRESS OF GET-REQUEST.
           MOVE LENGTH OF GET-REQUEST TO BAQ-REQUEST-LEN.
           SET BAQ-RESPONSE-PTR TO ADDRESS OF GET-RESPONSE.
           MOVE LENGTH OF GET-RESPONSE TO BAQ-RESPONSE-LEN.

      *---------------------------------------------------------------*
      * Call the communication stub                                   *
      *---------------------------------------------------------------*
      * Call the subsystem-supplied stub code to send
      * API request to zCEE
           CALL COMM-STUB-PGM-NAME USING
                BY REFERENCE   GET-INFO-OPER1
                BY REFERENCE   BAQ-REQUEST-INFO
                BY REFERENCE   BAQ-REQUEST-PTR
                BY REFERENCE   BAQ-REQUEST-LEN
                BY REFERENCE   BAQ-RESPONSE-INFO
                BY REFERENCE   BAQ-RESPONSE-PTR
                BY REFERENCE   BAQ-RESPONSE-LEN.
      * The BAQ-RETURN-CODE field in 'BAQRINFO' indicates whether this
      * API call is successful.

      * When BAQ-RETURN-CODE is 'BAQ-SUCCESS', response is
      * successfully returned and fields in RESPONSE copybook
      * can be obtained. Display the translation result.
           IF BAQ-SUCCESS THEN
              DISPLAY "EmployeeNumber: " employeeNumber2 of GET-RESPONSE
              DISPLAY "EmployeeName:   " employeeName2 of GET-RESPONSE
              DISPLAY "Address:        " Xaddress2 of GET-RESPONSE
              DISPLAY "Phone:          " phone2  of GET-RESPONSE
              DISPLAY "Date:           " Xdate2  of GET-RESPONSE
              DISPLAY "Amount:         " amount2 of GET-RESPONSE
              MOVE CEIBRESP of GET-RESPONSE to EIBRESP
              MOVE CEIBRESP2 of GET-RESPONSE to EIBRESP2
              DISPLAY "EIBRESP:        " EIBRESP
              DISPLAY "EIBRESP2:       " EIBRESP2
              DISPLAY "USERID:         " userIdentity2
              DISPLAY "HTTP CODE:      " BAQ-STATUS-CODE

      * Otherwise, some error happened in API, z/OS Connect EE server
      * or communication stub. 'BAQ-STATUS-CODE' and
      * 'BAQ-STATUS-MESSAGE' contain the detailed information
      *  of this error.
           ELSE
              DISPLAY "Error code: " BAQ-STATUS-CODE
              DISPLAY "Error msg:" BAQ-STATUS-MESSAGE
              MOVE BAQ-STATUS-CODE TO EM-CODE
              MOVE BAQ-STATUS-MESSAGE TO EM-DETAIL
              EVALUATE TRUE
      * When error happens in API, BAQ-RETURN-CODE is BAQ-ERROR-IN-API.
      * BAQ-STATUS-CODE is the HTTP response code of API.
                 WHEN BAQ-ERROR-IN-API
                   MOVE 'API' TO EM-ORIGIN
      * When error happens in server, BAQ-RETURN-CODE is
      * BAQ-ERROR-IN-ZCEE
      * BAQ-STATUS-CODE is the HTTP response code of
      * z/OS Connect EE server.
                 WHEN BAQ-ERROR-IN-ZCEE
                   MOVE 'ZCEE' TO EM-ORIGIN
      * When error happens in communication stub, BAQ-RETURN-CODE is
      * BAQ-ERROR-IN-STUB, BAQ-STATUS-CODE is the error code of STUB.
                 WHEN BAQ-ERROR-IN-STUB
                   MOVE 'STUB' TO EM-ORIGIN
              END-EVALUATE
              DISPLAY "Error origin:" EM-ORIGIN
           END-IF.

       MAINLINE-EXIT.
           MOVE BAQ-STATUS-CODE to RETURN-CODE.
           GOBACK.
       CALL-CEEENV.
           MOVE 5 TO functionCode.
           SET valuePointer to address of val
           CALL "CEEENV" USING functionCode,
                               envVariableNameLength,
                               envVariableName,
                               valueLength,
                               valuePointer,
                               feedbackCode.
           DISPLAY 'feedbackCode ' feedbackCode.

       CALL-CEEENV-END.
