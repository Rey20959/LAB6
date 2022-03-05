;Universidad del Valle
;Juan Emilio Reyes 
;20959
;Jose Morales   
;Programación de microcontroladores
;Lab6
; Creado: 01/03/2022
; Modificado: 04/03/2022
    
PROCESSOR 16F887
 #include <xc.inc>
 
 ;configuration word 1
  CONFIG FOSC=INTRC_NOCLKOUT	// Oscillador Interno sin salidas, XT
  CONFIG WDTE=OFF   // WDT disabled (reinicio repetitivo del pic)
  CONFIG PWRTE=OFF   // PWRT enabled  (espera de 72ms al iniciar)
  CONFIG MCLRE=OFF  // El pin de MCLR se utiliza como I/O
  CONFIG CP=OFF	    // Sin protección de código
  CONFIG CPD=OFF    // Sin protección de datos
  
  CONFIG BOREN=OFF  // Sin reinicio cuándo el voltaje de alimentación baja de 4V
  CONFIG IESO=OFF   // Reinicio sin cambio de reloj de interno a externo
  CONFIG FCMEN=OFF  // Cambio de reloj externo a interno en caso de fallo
  CONFIG LVP=OFF     // programación en bajo voltaje
 
 ;configuration word 2
  CONFIG WRT=OFF    // Protección de autoescritura por el programa desactivada
  CONFIG BOR4V=BOR40V // Reinicio abajo de 4V, (BOR21V=2.1V)

   ;----------------------------- macro división -------------------------------
  wdivl	macro divisor  
    movwf	var_02    
    clrf	var_02+1  
	
    incf	var_02+1   ; Las veces que ha restado
    movlw	divisor  

    subwf	var_02, f   ;se resta con el divisor y se guarda en F
    btfsc	CARRY    ;revisa si existe acarreo
    goto	$-4	; si no hay acarreo, la resta se repite
	
    decf	var_02+1,W    ; se guardan los resultados en W
    movwf	cociente   
    
    movlw	divisor	    
    addwf	var_02, W
    movwf	residuo
	
    endm
  
  ;------------------------- macro reset timer -----------------------------
  rest_tmr0 macro
    banksel PORTA
    movlw   220	    ;Tiempo deseado =4*tiempo de oscilación (256-N)(PRESCALER)
    movwf   TMR0    
    bcf	    T0IF    ; clear a la bandera luego del reinicio
    endm
    
 ;---------------------------- macro reset timer 1 ----------------------------
 rest_tmr1  macro
   movlw   0x83		;valores iniciales de conteo 2Hz
   movwf   TMR1H
   movlw   0x09
   movwf   TMR1L
   bcf	    TMR1IF 
  endm

 ;-------------------------------- variables ---------------------------------
 PSECT	udata_bank0
    segundos:	    DS 2
    microseg_tmr2:  DS 2
    banderas:	    DS 2
    display_var:    DS 3
    var_02:	    DS 3
    
      
    cociente:	DS 1
    residuo:	DS 1
    decena:	DS 1
    unit:	DS 2
    
    
  PSECT	udata_shr   ;common memory
    W_TEMP:	     DS 1   ; 1 byte
    STATUS_TEMP: DS 1	    ; 1 byte
    
    
 ;----------------------------- vector reset -------------------------------; 
 PSECT resVect, class=CODE, abs, delta=2 
 ORG 00h          ;posición en 0
    
 resetVec:        ;regresar a la posicion 0 
  PAGESEL main	 
  goto main     
 
    
;------------------------- vector interrupcion ----------------------------;

PSECT intVect, class=CODE, abs, delta=2  
ORG 04h          ;posicion en 0004h para interrpción

push:
    movwf   W_TEMP	  ; mueve a W
    swapf   STATUS, W	  ; swap para guerdar la bandera del status temporal
    movwf   STATUS_TEMP	  ; de swap a status temporal
    
isr:    
    btfsc   T0IF	;TMR0IF, revisa overflow
    call    int_t0
    
    btfsc   TMR1IF	;TMR1IF, revisa overflow
    call    int_t1
    
    btfsc   TMR2IF	;TMR2IF, revisa overflow
    call    int_t2
    
pop:
    swapf   STATUS_TEMP, W  
    movwf   STATUS	    
    swapf   W_TEMP, F	    
    swapf   W_TEMP, W	    
    retfie
    
 ;--------------------- sub rutina de interrpcion ----------------------------
 int_t0:
    rest_tmr0		;50 ms
    clrf    PORTD	;apagar displays para no mostrar traslapes
    btfss   banderas, 0 ;chequeo turno de display, si esta en 1 se pasa al display 1
    goto    display0	; si no, se queda en display 0
    
    btfss   banderas, 1
    goto    display1
    return

    
;unidad    
display0:
    clrf    banderas		; se limpia
    bsf	    banderas,	0	; se coloca en el bit menos significativo
    movf    display_var+0, W	; la varibale menos significtiva se mueve a W
    movwf   PORTA		; W a puerto A
    bsf	    PORTD,0		; transistor 1 en puerto D, pin 0
    return
    
;decena    
display1:
    bsf	    banderas,	1	; segundo bit en banderas
    movf    display_var+1, W	; la varibale se mueve a W
    movwf   PORTA		; W a puerto A
    bsf	    PORTD,  1		; transistor 2 en puerto D, pin 1
    clrf    banderas
    return
    
    
 int_t1:
    rest_tmr1	;100 ms
    incf    segundos	    ; se incrementa la variable
    movf    segundos,   W   ; se guarda en W
    sublw   10		;100 ms * 10 = 1 s y se resta 10 a la variable
    btfsc   ZERO    ; si la resta da 0, no regresa  a las demás instrucciones
    goto    return_t0 ;si da 1 se regresa a las demás instrucciones
    incf    PORTB	; incrementa el puerto B
    return
    
 int_t2:
    clrf    TMR2 ;50 ms
    bsf	    TMR2IF
    incf    microseg_tmr2
    movf    microseg_tmr2, W
    sublw   10		; 10 * 50 ms = 500 ms
    btfss   ZERO
    goto    return_t0	    ; si rebasa el segundo regresa
    clrf    microseg_tmr2   
    btfsc   PORTC, 0	   ;revisa si esta apagado el pin 0 del port C 
    goto    off		    ; si esta encendido va a off
    bsf	    PORTC, 0	    ; si esta apagado lo enciende
    return
    
 off:
    bcf	    PORTC, 0	    ; si esta encendido lo apaga
    return
    
 return_t0:	;return a las instrucciones
    return
 ;--------------------------- CONFIGURACIÓN --------------------------------
 
 PSECT code, delta=2, abs 
 ORG 100h	 ;posicion del codigo 100
 
 ;------------------------------- tabla ---------------------------------- 
 tabla:
    clrf    PCLATH
    bsf	    PCLATH, 0	;PCLATH =01    PCL=02
    andlw   0x0f
    addwf   PCL		;PC = PCLATH + PCL + W
    retlw   00111111B	;0
    retlw   00000110B	;1
    retlw   01011011B	;2
    retlw   01001111B	;3
    retlw   01100110B	;4
    retlw   01101101B	;5
    retlw   01111101B	;6
    retlw   00000111B	;7 
    retlw   01111111B	;8
    retlw   01101111B	;9
    retlw   01110111B	;A
    retlw   01111100B   ;B
    retlw   00111001B	;C
    retlw   01011110B	;D
    retlw   01111001B	;E
    retlw   01110001B	;F
    
;------------------------ configuracion ---------------------------------
 main:
    call    config_io
    call    config_reloj
    call    config_tmr0
    call    config_int_enable
    call    config_tmr1
    call    config_tmr2
    banksel PORTA
    
 ;---------------------------  LOOP PRINCIPAL -------------------------------- 

 loop:
    call    decenas		    ; se llama a la divisón 
    call    preparar_displays	    ;se llama a prerar display
    goto    loop	; loop forever

 ;------------------- SUB RUTINAS --------------------------------------------
 preparar_displays: 
    ;Se preparan los display para como apareceran 
    ;De binario a decimal que aparece en los display
    movf    decena, W
    call    tabla
    movwf   display_var
    
    movf    unit, W
    call    tabla
    movwf   display_var+1
    return
 
  decenas:    ;decenas 
    movf    segundos, W
    wdivl   10
    movf    cociente, W
    movwf    decena
    movf    residuo, W
    
  unidades: ;unidades
    movwf   unit
    return
    
 config_io:
    ; configuracion de entradas y salidas
    banksel ANSEL
    clrf    ANSEL	; pines digitales
    clrf    ANSELH
			
    banksel TRISA
    clrf    TRISA	;PORTA como salida 
    clrf    TRISB
    clrf    TRISC
    bcf     TRISD,0	; PORTD 0 como salida para transistores
    bcf     TRISD,1	; PORTD 1 como salida para transistores
    
    banksel PORTA	;Clear a todos los puertos 
    clrf    PORTA
    clrf    PORTB
    clrf    PORTC
    clrf    PORTD
    return  
    
    
  config_reloj: ;configurar el oscilador
    banksel OSCCON  ;se configura a 1 MHz =100    
    bsf IRCF2	    ; OSCCON, 6
    bcf IRCF1	    ; OSCCON, 5
    bcf IRCF0	    ; OSCCON, 4
    bsf SCS	    ; reloj interno
    return
    
 config_tmr0: 
    banksel TRISA   ; 50 ms
    bcf	    T0CS    ;colocar el reloj interno
    bcf	    PSA	    ;assignar el prescaler para el modulo timer0
    bsf	    PS2
    bsf	    PS1
    bsf	    PS0	    ;PS = 111, prescalrer = 1:256 
    rest_tmr0
    return 
 
 config_tmr1:
    banksel PORTA	;2Hz
    bcf	    TMR1GE	; siempre contando
    bsf	    T1CKPS0	; prescale2 1:8
    bsf	    T1CKPS1
    bcf	    T1OSCEN	;reloj interno
    bcf	    TMR1CS
    bsf	    TMR1ON	;prender timer 1
    rest_tmr1  
    return
  
  config_tmr2:
    banksel PORTA	;20Hz
    bsf	    TOUTPS3	; prescaler 1:16
    bsf	    TOUTPS2
    bsf	    TOUTPS1
    bsf	    TOUTPS0
    
    bsf	    TMR2ON
    
    bsf	    T2CKPS1	; prescaler 1:16
    bsf	    T2CKPS0
    
    banksel TRISB
    movwf   196
    movwf   PR2
    bcf	    TMR2IF
    return
    
  config_int_enable:
    banksel TRISA
    bsf	    TMR1IE	; interrupcion tmr1
    bsf	    TMR2IE	; interrupcion tmr2
    banksel PORTA
    bcf	    T0IF	; bandera tmr0
    bcf	    TMR1IF	; bandera tmr1
    bcf	    TMR2IF
    
    bsf	    T0IE	; habilitar interrupcion tmr0
    bsf	    PEIE	;interrupciones perifericas
    bsf	    GIE		;HABILITA interrupciones globales
       
    return
   
    
 END