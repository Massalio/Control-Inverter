.INCLUDE "M32DEF.INC"

.CSEG
.ORG 0x00
		JMP PROGRAMA

.ORG 0X0A
		JMP TIMER2_OVERFLOW

;---------------------------------------------------------------------------------

.ORG 0x30

PROGRAMA:

	LDI R16,HIGH(RAMEND)
	OUT SPH,R16
	LDI R16,LOW(RAMEND)
	OUT SPL,R16

;---------------------------------------------------------------------------------

;Configuración timer2 tiempo real

	CLI

	LDI R16,0x00
	OUT TIMSK,R16		;deshabilitar interrupciones timer2
	
	LDI R16,0b00001000	;setear bit AS2 para elegir el oscilador externo
	OUT ASSR,R16		;como fuente de clock

	LDI R16,0x00		;resetear timer
	OUT TCNT2,R16
	
	LDI R16,0b00000101	;prescaler 128 para que ocurra overflow cada 1 seg
	OUT TCCR2,R16
	
ESPERA:	IN R16,ASSR		;esperar que se actualice ASSR
	CPI R16,0b00001000
	BRNE ESPERA		
	
	LDI R16,0b01000000
	OUT TIMSK,R16		;habilitar interrupción timer2 overflow

;---------------------------------------------------------------------------------

;Otras configuraciones

	SBI DDRA,1		;configurar pin enable motor como salida
	SBI DDRC,1		;configurar pin led motor como salida
	SBI DDRD,5		;configurar pin PWM OC1A como salida
	SBI DDRD,4		;configurar pin PWM OC1B como salida
	CBI DDRA,4		;configurar pin corrientte motor como entrada

	LDI R16,0b10000110
	OUT ADCSRA,R16		;habilitar ADC y seleccionar velocidad (8M/64=125k)

	LDI R16,0b11000100	;configuración ADC:
	OUT ADMUX,R16		;Vref=2.56 V, entrada ADC4, justificado derecha

	SEI			;habilitar interrupciones

;---------------------------------------------------------------------------------

	JMP MOTOR

FIN:	RJMP FIN

;---------------------------------------------------------------------------------

;Subrutina hacer girar el motor por x segundos

MOTOR:	SBI PORTA,1		;encender led motor	
	SBI PORTC,1		;habilitar motor

	
	LDI R16,0xDF		;duty cycle
	OUT OCR1AL,R16
	LDI R16,0x00		;duty cycle
	OUT OCR1AH,R16

	LDI R16,0b10000001	;encender timer1 en PC PWM no inv por OC1A
	OUT TCCR1A,R16		;top 0xFF, no prescaler
	LDI R16,0b00000001
	OUT TCCR1B,R16		
	
	LDI R20,0x0A		;setear contador de tiempo de adelanto 10 seg

ON:	CPI R20,0x00		;salta si terminó el tiempo de adelanto
	BREQ END	

	LDI R22,0x08		;setear contador muestras ADC
	LDI R23,0x03		;setear contador divisiones (lo repite 3 veces p dividir x 8)
	
	LDI R18,0x00		
	LDI R19,0X00

READ:	SBI ADCSRA,ADSC		;iniciar conversión

WAIT:	SBIS ADCSRA,ADIF	;monitorear flag de fin de conversión
	RJMP WAIT		

	SBI ADCSRA,ADIF		;clear flag fin de conversión

	IN R16,ADCL		;leer corriente en el motor
	IN R17,ADCH

DIV:	LSR R17			;dividir por cantidad de muestras
	ROR R16
	DEC R23
	BRNE DIV

	ADD R18,R16		;sumar muestras
	ADD R19,R17
	
	DEC R22			
	BRNE READ		;salta si falta leer más muestras
	
	CPI R19,0x00		;salta si la corriente no supera la máxima
	BREQ ON			;(Imáx aprox. 1.36 A = 01 0000 0000)

	LDI R16,0b00100001	;invertir giro motor si la corriente
	OUT TCCR1A,R16		;supera la máxima

	LDI R21,0x03		;setear contador de tiempo de retroceso

AGAIN:	CPI R21,0x00
	BREQ HERE		;esperar a que termine el tiempo
	RJMP AGAIN		;de retroceso

HERE:	LDI R16,0b10000001
	OUT TCCR1A,R16		;invertir timer nuevamente y
	RJMP ON			;volver a medir corriente

END:	LDI R16,0x00
	OUT TCCR1B,R16		;parar motor
	OUT TCCR1A,R16
	
	CBI PORTA,1		;deshabilitar motor
	CBI PORTC,1		;apagar led motor

	RET

;---------------------------------------------------------------------------------

;Interrupción timer2 overflow

TIMER2_OVERFLOW:
	IN R24,TCCR1A
	CPI R24,0b10000001
	BRNE REV
	DEC R20
REV:	CPI R24,0b00100001
	BRNE OFF
	DEC R21
OFF:	RETI
	
;---------------------------------------------------------------------------------



