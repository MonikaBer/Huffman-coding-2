section .data

section .bss
byte1:              resb 1       ;bajt kodu odczytany z pliku
byte2:              resb 1       ;bajt kodu odczytany z pliku
byte3:              resb 1       ;bajt kodu odczytany z pliku
bitsInCurrByteCode: resb 4       ;liczba zapisanych bitów w bieżącym bajcie kodu
mask:               resb 4       ;maska do wyłuskiwania bitu z rejestru
index:              resb 4       ;index do chodzenia po array  
file1:              resb 4       ;deskryptor pliku niezakodowanego
file2:              resb 4       ;deskryptor pliku zakodowanego
temp1:              resb 4
temp2:              resb 4
temp3:              resb 4
temp4:              resb 4
buffer:      	    resb 1       
array:       	    resb 10220   ;w niej drzewo Huffmana
								 ;(2000*2-1)*(20) (511 elementów typu: (częstość, lewy syn, 
								 ;prawy syn, znak, rodzic) każdy węzeł ma 5*4bity )	

section	.text
global decode
decode:
	push ebp
	mov	ebp, esp

openFileToDecode:
	mov eax, 5    ;otwarcie pliku
	mov ebx, [ebp+8]     ;nazwa pliku do zdekodowania 
	xor ecx, ecx    ;0 - read-only
	mov edx, 0644o      ;czytanie przez wszystkich (ósemkowo)
    int 0x80              
	mov dword [file1], eax  ;deskryptor pliku zakodowanego

;należy odczytać drzewo Huffmana zapisane w headerze pliku zakodowanego (zapisanie go do array)
readHeader:
	mov eax, 3       ;czytanie z pliku
	mov ebx, dword [file1]       ;deskryptor pliku zakodowanego
	mov ecx, array   ;tablica na drzewo Huffmana
	mov edx, 10220     ;rozmiar array
	int 0x80

;poustawianie rejestrów do chodzenia po drzewie Huffmana (kod kolejnego znaku trzeba odczytać)
	mov dword [index], 0    ;index do chodzenia po array (drzewie Huffmana) 

;----------------------------------------------------------------------------------------------------
;otwarcie pliku do zapisu tekstu zdekodowanego
    mov eax, 5       ;otwarcie pliku  
	mov ebx, [ebp+12]        ;nazwa pliku 
	mov ecx, 65       ;O_WRONLY
	mov edx, 0664o         ;zapis przez wszystkich (ósemkowo)
	int 0x80
	mov [file2], eax

;----------------------------------------------------------------------------------------------------
beginReadingCodedText:
;teraz będzie czytany tekst zakodowany z pliku (na początku 3 pierwsze bajty, a potem po jednym 
;bajcie będzie doczytywane)	
	mov eax, 3       ;czytanie z pliku
	mov ebx, dword [file1]       ;deskryptor pliku zakodowanego
	mov ecx, buffer  ;bufor do czytania z pliku
	mov edx, 1
	int 0x80          ;w eax jest liczba przeczytanych znaków
	cmp eax, 0
	je endReadFileToDecode   ;nie przeczytano nic
	xor eax, eax
	mov al, [buffer]
	mov byte [byte1], al           

	mov eax, 3       ;czytanie z pliku
	mov ebx, dword [file1]       ;deskryptor pliku zakodowanego
	mov ecx, buffer  ;bufor do czytania z pliku
	mov edx, 1
	int 0x80          ;w eax jest liczba przeczytanych znaków
	mov al, [buffer]
	mov byte [byte2], al                                                      

;2 pierwsze bajty kodu są odpowiednio w byte1 i byte2
readCodedText:
	mov bl, byte [byte1]
	mov edi, ebx      ;bieżący bajt z pliku zakodowanego w edi

;przeczytanie kolejnego bajtu (w celu sprawdzenia czy bieżący bajt nie jest ostatnim)
	mov eax, 3       ;czytanie z pliku
	mov ebx, dword [file1]       ;deskryptor pliku zakodowanego
	mov ecx, buffer  ;bufor do czytania z pliku
	mov edx, 1
	int 0x80          ;w eax jest liczba przeczytanych znaków
	cmp eax, 0
	je handleLastCodedByte   ;1 bajt tekstu zakodowanego jest zarazem ostatnim bajtem kodu
	
	;3 pierwsze bajty będą odpowiednio w  byte1, byte2, byte3
	mov bl, [buffer]                                                        
	mov byte [byte3], bl
	mov bl, byte [byte2]
	mov byte [byte1], bl
	mov bl, byte [byte3]
	mov byte [byte2], bl
	     
	mov dword [mask], 128       ;maska do wyciągania bitów z bajtu kodu (na początku 10000000)
	mov dword [bitsInCurrByteCode], 0

loopForCurrentByteOfCode:
	mov esi, dword [index]
	lea esi, [array + esi + 12]   ;przesunięcie adresu na pole 'znak' bieżącego węzła
	mov edx, dword [esi]       ;pobranie znaku w bieżącym węźle
	mov dword [temp1], edx
	cmp edx, 2000
	jl storeByteToResultFile     ;doszliśmy do liścia czyli do znaku
	
	mov edx, dword [mask]
	mov ebx, edi
	and ebx, edx   ;w  0 jeśli bit wskazany przez maskę był '0' lub coś różnego od zera gdy było '1'
	cmp ebx, 0
	je goRight

goLeft:
	add dword [index], 4      ;index wskazuje na pole węzła w array, w którym jest zapisany adres lewego 
	                          ;syna tego węzła
	jmp prepareToReadNextBit

goRight:
	add dword [index], 8     ;index wskazuje na pole węzła w array, gdzie zapisano adres prawego syna tego węzła		
	
prepareToReadNextBit:
	mov dword [temp3], ecx
	mov ecx, dword [index]
	lea ebx, [array + ecx]
	mov ecx, [ebx]              ;adres (index) w array wskazujący na początek lewego syna
	mov ebx, ecx
	mov ecx, dword [temp3]
	mov dword [index], ebx    ;wskazuje na jeden węzeł poniżej (bo idziemy od korzenia do liścia)	
	inc dword [bitsInCurrByteCode]         ;inkrementacja ilości przeczytanych bitów bieżącego bajtu kodu 
	cmp dword [bitsInCurrByteCode], 8
	je  readCodedText  ;jeśli przeczytano już cały bajt kodu to skocz w celu pobrania kolejnego 
	                   ;zakodowanego bajtu z pliku
	
	mov ebx, dword [mask]
	shr ebx, 1           ;zmień maskę w celu pobrania kolejnego bitu z bajtu zakodowanego
	mov dword [mask], ebx
	jmp loopForCurrentByteOfCode   ;skocz w celu wyciągnięcia kolejnego bitu z bajtu zakodowanego
	
;zapis znaku zdekodowanego do pliku z tekstem zdekodowanym
storeByteToResultFile:
	mov edx, dword [temp1]
	shr edx, 2             ;zmniejszenie adresu odpowiadającemu znakowi (dzielenie przez 4)
	mov dword [index], 0     ;powrót indexu chodzenia po drzewie do roota
	mov byte [buffer], dl
	
	mov eax, 4        ;zapis do pliku
	mov ebx, [file2]       ;deskryptor pliku z tekstem zdekodownanym
	mov ecx, buffer   ;buffer zawiera znak zdekodowany
	mov edx, 1          ;zapis do pliku po 1 zdekodowanym znaku
	int 0x80

	cmp dword [bitsInCurrByteCode], 8
	je readCodedText   ;jeśli przeczytano już cały bajt kodu to skocz w celu pobrania kolejnego 
	                   ;zakodowanego bajtu z pliku
	jmp loopForCurrentByteOfCode   ;skocz w celu wyciągnięcia kolejnego bitu z bajtu zakodowanego

handleLastCodedByte:
;w r14 jest ostatni bajt kodu, a w r9 jest liczba znaczących bitów w ostatnim bajcie kodi
	mov dword [mask], 128     ;maska do wyciągania bitów z bajtu kodu (na początku 10000000)
	mov dword [bitsInCurrByteCode], 0   ;licznik przeczytanych bitów z bieżącego bajtu kodu 

loopForLastByteOfCode:
	mov ebx, dword [mask]
	mov dword [temp4], edi
	and edi, ebx    ;w edi będzie 0 jeśli bit wskazany przez maskę był '0' lub coś różnego od zera gdy było '1'
	cmp edi, 0
	je goRight2

goLeft2:
    mov edi, dword [temp4]
	mov dword [temp3], ebx
	mov ebx, dword [index]
	add ebx, 12
	lea eax, [array + ebx]    ;przesunięcie adresu żeby wskazywał na pole 'znak' bieżącego węzła
	mov eax, [eax]
	mov ebx, dword [temp3]
	cmp eax, 2000
	jl storeCharToResultFile   ;doszliśmy do liścia czyli do znaku (w eax jest wartość znaku)      
	mov dword [temp3], ebx
	add dword[index], 4
	mov ebx, dword [index]	
	lea edx, [array + ebx]  ;adres pola węzła w array, w którym jest zapisany adres lewego syna tego węzła
	mov edx, [edx]                ;adres (index) w array wskazujący na początek lewego syna
	mov ebx, dword [temp3]
	mov dword [index], edx      ;wskazuje na jeden węzeł poniżej (bo dekodując idziemy od korzenia do liścia)
	jmp prepareToReadNextBit2	

goRight2:
	mov edi, dword [temp4]
	mov dword [temp3], ebx
	mov ebx, dword [index]
	add ebx, 12
	lea eax, [array + ebx]    ;przesunięcie adresu żeby wskazywał na pole 'znak' bieżącego węzła
	mov eax, [eax]
	mov ebx, dword [temp3]
	cmp eax, 2000
	jl storeCharToResultFile   ;doszliśmy do liścia czyli do znaku (w edi jest wartość znaku)
	add dword [index], 8    ;adres pola węzła w array, w którym jest zapisany adres prawego syna tego węzła	
	mov dword [temp3], ebx
	mov ebx, dword [index]
	lea edx, [array + ebx]
	mov ebx, dword [temp3]
	mov edx, [edx]            ;adres (index) w array wskazujący na początek lewego syna
	mov dword [index], edx      ;wskazuje na jeden węzeł poniżej (bo dekodując idziemy od korzenia do liścia)		

prepareToReadNextBit2:
	inc dword [bitsInCurrByteCode]   ;inkrementacja ilości przeczytanych bitów ostatniego bajtu tekstu zakodowanego 
	mov edx, dword [mask]
	shr edx, 1      ;zmień maskę w celu pobrania kolejnego bitu z bajtu zakodowanego
    mov dword [mask], edx
	jmp loopForLastByteOfCode   ;skocz w celu wyciągnięcia kolejnego bitu z ostatniego bajtu kodu
	
;zapis znaku zdekodowanego do pliku z tekstem zdekodowanym
storeCharToResultFile:
	shr eax, 2    ;zmniejszenie adresu odpowiadającemu znakowi (w eax jest wartość znaku) 
	mov byte [buffer], al

	mov dword [index], 0   ;powrót indexu chodzenia po drzewie do roota
	mov eax, 4          ;zapis do pliku
	mov ebx, dword [file2]      ;deskryptor pliku z tekstem zdekodowanym
	mov ecx, buffer   ;w buforze jest odkodowany znak gotowy do zapisu do pliku zdekodowanego
	mov edx, 1          ;zapisywanie po 1 bajcie (po jednym zdekodowanym znaku)
	int 0x80

	mov bl, byte [byte2]
	cmp dword [bitsInCurrByteCode], ebx    ;gdy przeczytano cały bajt kodu to skocz aby pobrać kolejny zakodowany bajt z pliku
	jl loopForLastByteOfCode   ;jeśli jeszcze nie przeczytaliśmy wszystkich znaczących bitów 
	                            ;w ostatnim bajcie kodu to skocz do 'loopForLastByteOfCode'

;zamknięcie plików
endReadFileToDecode:
	mov eax, 6         ;zamknięcie pliku zakodowanego
	mov ebx, dword [file1]         ;deskryptor pliku
	int 0x80

	mov eax, 6         ;zamknięcie pliku z tekstem odkodowanym
	mov ebx, dword [file2]         ;deskryptor pliku
	int 0x80

statistics:
		
end:
	pop	ebp	
	ret


;============================================
; STOS
;============================================
;
; wieksze adresy
; 
;  |                                 |
;  | ...                         	 |
;  -------------------------------
;  | parametr funkcji - char *input  | EBP+8
;  -------------------------------
;  | adres powrotu                   | EBP+4
;  -------------------------------
;  | zachowane ebp                   | EBP, ESP
;  -------------------------------
;  | ... tu ew. zmienne lokalne      | EBP-x
;  |                                 |
;
; \/                         \/
; \/ w ta strone rosnie stos \/
; \/                         \/
;
; mniejsze adresy
;
;
;============================================
