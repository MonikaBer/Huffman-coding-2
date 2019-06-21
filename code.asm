section .data

section .bss
indexForBuff:          resb 4       
counterForBuff:        resb 4		
bytesCounter:          resb 4       ;liczba bajtów kodu bieżącego znaku    
indForArrayWithCode:   resb 4		;index dla bufora z pełnymi bajtami kodu dla bieżącego znaku
bitsInCurrByteCode:    resb 4		;liczba zapisanych bitów w bieżącym bajcie kodu
codeLen:               resb 4       ;długość kodu bieżącego znaku
mask:                  resb 4		;maska do wyłuskiwania bitu z rejestru
currByteCode:          resb 4		;bieżący bajt kodu dla bieżacego znaku
index:                 resb 4       ;index do chodznia po array  
file1:                 resb 4       ;deskryptor pliku niezakodowanego
file2:                 resb 4       ;deskryptor pliku zakodowanego
temp1:                 resb 4
temp2:                 resb 4
temp3:                 resb 4
temp4:                 resb 4
ifOrdered:             resb 4
index1ForCode:         resb 4       ;index początkowy do sortowania bufora 'arrayWithCode'
index2ForCode:         resb 4       ;index końcowy do sortowania bufora 'arrayWithCode'
indexForCode:          resb 4       ;index do odczytu kodu znaku z bufora 'arrayWithCode'
i:                     resb 4       ;indeks do tworzenia drzewa Huffmana
j:                     resb 4       ;indeks do tworzenia drzewa Huffmana
buffer1000:    	       resb 1000        
buffer:      	       resb 1         
array:       	       resb 10220  ;w niej drzewo Huffmana
								   ;(2000*2-1)*(20) (511 elementów typu: (częstość, 
                                   ;lewy syn, prawy syn, znak, rodzic) każdy węzeł ma 5*4bity)	
arrayWithCode:         resb 32     ;255b+1b (żeby było do pełnych bajtów, czyli w sumie 32B, bo
								   ;kod dla 1 znaku) - tu trzymane pełne bajty kodu bieżącego 
								   ;znaku
freqArray:  	       resb 1024   ;częstość znaków dopiero wczytanych
								   ;(będą tu zera na pozycjach znaków które nie wystąpiły) 	     	   
byteBufferForCode:     resb 255    ;bufer dla kodu danego znaku, gdzie każdy bajt odpowiada 
								   ;liczbie '1' lub '0'
howManyLetters:        resb 4      ;jak dużo wszystkich znaków  
howManyChars:          resb 4      ;jak dużo rodzajów znaków 


section	.text
global code
code:
	push ebp
	mov	ebp, esp
	
openFile:
	mov eax, 5                 ;otwarcie pliku niezakodowanego
    mov ebx, [ebp+8]         ;nazwa pliku
	xor ecx, ecx               ;0 - read-only
	mov edx, 0644o           ;czytanie przez wszystkich (ósemkowo)      
    int 0x80              
	mov dword [file1], eax   ;deskryptor pliku

readFile:
	mov eax, 3
	mov ebx, dword [file1]   ;deskryptor pliku niezakodowanego
	mov ecx, buffer1000        ;bufor do czytania z pliku
	mov edx, 1000            ;rozmiar bufora
	int 0x80
	mov dword [counterForBuff], eax
	mov dword [indexForBuff], 0
	cmp eax, 0               ;przeczytano wszystko z pliku
	je endReadFile

readCharFromBuffer:
	xor eax, eax
	mov  ebx, dword [indexForBuff]
	lea ebx, [buffer1000 + ebx]
	mov al, byte [ebx]           ;pobierz 1 bajt z bufora
	dec dword [counterForBuff]
	inc dword [indexForBuff]
	shl eax, 2                   ;zwiększ adres do 32 b (mnożenie przez 4)
	lea eax, [freqArray + eax] 
	mov ebx, dword [eax]
	inc ebx
	mov dword [eax], ebx
	mov ebx, dword [howManyLetters]     ;wartość licznika 
	inc ebx                           ;inkrementacja licznika
	mov dword [howManyLetters], ebx     ;zapisanie bieżącej wartości licznika do zmiennej
	cmp dword [counterForBuff], 0
	jg readCharFromBuffer
	jmp readFile

endReadFile:                  
    mov eax, 6
	mov ebx, dword [file1]
	int 0x80     ;zamknięcie pliku	

;------------------------------------------------------------------------------------  
	mov eax, freqArray     ;adres do chodzenia po freqArray
	mov ebx, array         ;adres do chodzenia po tabeli array     
	

;wyszukanie rodzajów znaków, które wystąpiły w pliku
findCharsLoop: 
	mov ecx, dword [eax]  
	cmp ecx, 0                 ;częstość bieżacego znaku jest zerowa
	je notWriteToArray

writeToArray:	
	inc dword [howManyChars]   ;inkrementacja licznika rodzajów znaków    
	mov [ebx], ecx       ;zapis do array częstości bieżącego znaku
	mov dword [temp1], ecx
	mov ecx, freqArray
	mov edx, eax
	sub edx, ecx              ;w edx jest bieżący znak  
	mov ecx, dword [temp1]
	add ebx, 4           ;następne pole bieżącego węzła          
	mov dword [ebx], 0        ;wyzerowanie miejsca dla lewego syna
	add ebx, 4           ;następne pole bieżącego węzła 
	mov dword [ebx], 0        ;wyzerowanie miejsca dla prawego syna
	add ebx, 4           ;następne pole bieżącego węzła 
	mov dword [ebx], edx      ;zapisanie znaku
	add ebx, 4           ;następne pole bieżącego węzła 
	mov dword [ebx], 0        ;wyzerowanie miejsca dla rodzica
	add ebx, 4           ;adres początku kolejnego węzła w array
	
notWriteToArray:
	add eax, 4                   ;adres kolejnego elementu z freqArray
	mov ecx, eax
	mov dword [temp1], edi
	mov edi, freqArray
	sub ecx, edi     ;długość przeczytanej części freqArray
	mov edi, dword [temp1]
	cmp ecx, 1024                ;spr czy koniec freqArray
	jl findCharsLoop               ;jeszcze nie koniec freqArray  

;uzupełniamy wartości pól dla niepotrzebnych elementów w array (druga połowa)
prepareToCreateTree:
	mov dword [ebx], 0         ;wyzerowanie częstości
	add ebx, 4             ;następne pole bieżącego węzła 
	mov dword [ebx], 0         ;wyzerowanie miejsca w array dla lewego syna
	add ebx, 4             ;następne pole bieżącego węzła 
	mov dword [ebx], 0         ;wyzerowanie miejsca w array dla prawego syna
	add ebx, 4             ;następne pole bieżącego węzła 
	mov dword [ebx], 2000      ;zapisanie do array 2000 żeby odróżnić pomocnicze węzły od liści
	add ebx, 4             ;następne pole bieżącego węzła 
	mov dword [ebx], 0         ;wyzerowanie miejsca w array dla rodzica
	add ebx, 4            ;adres kolejnego węzła w array

	mov dword [temp1], edi 
	mov edi, array
	mov ecx, ebx
	sub ecx, edi                ;długość uzupełnionej części tablicy array
	mov edi, dword [temp1]
	cmp ecx, 10220            ;spr czy koniec array
	jl prepareToCreateTree      ;array jeszcze nie uzupełniona

;array uzupełniona
;------------------------------------------------------------------------------------------------------
setIndexes:
	mov eax, dword [howManyChars]
	dec eax                ;liczba wczytanych rodzajów znaków - 1       
	mov dword [i], eax   ;indeks i  
	mov dword [j], eax   ;indeks j

;uporządkowanie pierwszej połowy węzłów (podstawowych) i zbudowanie drzewa
buildTree:
	cmp dword [i], 1
	jl parentForRoot       ;jeśli i<1 to wyjdź z pętli

sort:
	mov eax, array                ;adres do chodzenia po array
	mov dword [ifOrdered], 1        ;czy lista jest uporządkowana (1- tak, 0 - nie)

checkCondition:
	mov ebx, dword [i]
	imul ebx, 20            ;sortowanie array do indeksu 20i 
	cmp ebx, 20
	jle checkIfOrdered

	sub ebx, 20
	mov dword [temp1], edi 
	mov ecx, eax
	mov edi, array
	sub ecx, edi
	mov edi, dword [temp1]
	cmp ecx, ebx           ;spr czy bieżący element jest końcem listy
	jge checkIfOrdered       ;koniec więc sprawdzić czy uporządkowane malejąco po częstościach
       
	mov ebx, dword [eax]      ;częstość bieżącego elem
	add eax, 20               ;eax wskazuje na częstość nast elem
	mov ecx, dword [eax]
	cmp ebx, ecx    ;spr czy częstość bieżącego elem jest wieksza równa od częstości nast elem
	jge checkCondition       ;tak, więc nie trzeba zamieniać

	;trzeba zamienić elementy miejscami (zamiana częstości, znaków, synów i rodziców
	;zamiana częstości
	mov dword [eax], ebx
	sub eax, 20
	mov dword [eax], ecx
	add eax, 12
	;teraz zamiana znaków
	mov ebx, dword [eax]  ;1 znak
	add eax, 20
	mov ecx, dword [eax]  ;2 znak
	mov dword [eax], ebx
	sub eax, 20
	mov dword [eax], ecx
	;zamiana lewych synów
	sub eax, 8
	mov ebx, dword [eax]
	add eax, 20
	mov ecx, dword [eax]
	mov dword [eax], ebx
	sub eax, 20
	mov dword [eax], ecx
	;zamiana prawych synów
	add eax, 4
	mov ebx, dword [eax]
	add eax, 20
	mov ecx, dword [eax]
	mov dword [eax], ebx
	sub eax, 20
	mov dword [eax], ecx
	;zamiana rodziców
	add eax, 8
	mov ebx, dword [eax]
	add eax, 20
	mov ecx, dword [eax]
	mov dword [eax], ebx
	sub eax, 20
	mov dword [eax], ecx
	sub eax, 16               ;powrót do początku bieżącego węzła
	mov dword [ifOrdered], 0      ;zaznaczamy że lista nie była uporządkowana
	add eax, 20               ;nast węzeł
	jmp checkCondition

checkIfOrdered:	
	cmp dword [ifOrdered], 0
	je sort

createProperTree: 
	mov ebx, dword [i]
	dec ebx         ;i-1
	imul ebx, 20                                              
	mov ecx, dword [j]
	inc ecx         ;j+1
	imul ecx, 20            

	lea ebx, [array + ebx]
	lea ecx, [array + ecx]                               
	;przerzucenie częstości  
	mov edi, [ebx]
	mov [ecx], edi
	;przerzucenie lewego syna
	add ebx, 4
	add ecx, 4
	mov edi, [ebx]
	mov [ecx], edi
	;przerzucenie prawego syna
	add ebx, 4
	add ecx, 4
	mov edi, [ebx]
	mov [ecx], edi
	;przerzucenie znaku
	add ebx, 4
	add ecx, 4
	mov edi, [ebx]
	mov [ecx], edi
	;przerzucenie rodzica
	add ebx, 4
	add ecx, 4
	mov edi, [ebx]
	mov [ecx], edi
	;sumowanie częstości
	sub ebx, 16             ;20(i-1)	
	mov ecx, dword [i]
	imul ecx, 20             ;20i                           
	lea ecx, [array + ecx]
	mov edi, [ebx]
	mov esi, [ecx]
	add edi, esi
	mov [ebx], edi
	;wpisanie '2000' zamiast poprzedniego znaku w pole 'znak' węzła 
	add ebx, 12
	mov dword [ebx], 2000                                    
	;ustawienie lewego syna
	sub ebx, 8
	mov edi, dword [i]
	imul edi, 20                                               
	mov [ebx], edi       ;20i
	;ustawienie prawego syna
	add ebx, 4
	mov edi, dword [j]
	inc edi                                                       
	imul edi, 20                                                 
	mov [ebx], edi       ;20(j+1) 
	;ustawienie rodzica dla lewego syna
	sub ebx, 4
	mov esi, dword [i]
	dec esi
	imul esi, 20              ;20(i-1)                           
	mov edi, [ebx]
	add edi, 16
	lea edx, [array + edi] 
	mov [edx], esi
	;ustawienie rodzica dla prawego syna
	add ebx, 4
	mov edi, [ebx]
	add edi, 16
	lea edx, [array + edi]
	mov [edx], esi
	dec dword [i]                  ;i--
	inc dword [j]                  ;j++
	jmp buildTree

;wpisanie w pole 'rodzic' dla roota wartość '15000'
parentForRoot:
	xor eax, eax           
	add eax, 16
	lea edi, [array + eax]
	mov dword [edi], 15000

;------------------------------------------------------------------------------------------------------
codeFile:
	mov eax, 5    ;otwarcie pliku do którego będzie zapisywany zakodowany tekst   
    mov ebx, [ebp+12]   ;nazwa pliku
	mov ecx, 65    ;WRITE do pliku
	mov edx, 0644o    ;zapis przez wszystkich (ósemkowo)
    int 0x80     
	mov dword [file2], eax   ;deskryptor kodowanego pliku

;czytanie po kolei znaków niezakodowanych
writeCodesToFile:
	mov eax, 5         ;ponowne otwarcie pliku z niezakodowanym tekstem
	mov ebx, [ebp+8]      ;nazwa pliku
	xor ecx, ecx         ;0 - O_RDONLY
	mov edx, 0644o       ;czytanie przez wszystkich (ósemkowo)
	int 0x80
	mov dword [file1], eax   ;deskryptor niezakodowanego pliku

;najpierw do pliku zostanie zapisane drzewo Huffmana
	mov eax, 4        ;zapis do pliku
	mov ebx, dword [file2]  
	mov ecx, array    
	mov edx, 10220
	int 0x80

;----------------------------------------------------------------------------------------------------
	mov dword [mask], 128

readFile2Loop:
;ustawienie rejestrów do czytania z pliku
	mov eax, 3
	mov ebx, dword [file1]       ;deskryptor pliku niezakodowanego
	mov ecx, buffer  ;adres bufora do którego będziemy wprowadzać przeczytany znak z pliku
	mov edx, 1
	int 0x80         ;w eax liczba przeczytanych bajtów

	cmp eax, 0       ;jeśli nie wczytano żadnego znaku to wygeneruj kod ostatniego znaku
	je handleLastCurrentByteOfCode  

;obsłużenie bufora (bieżącego znaku wczytanego z pliku)
	mov al, byte [buffer]          ;w al jest wczytany znak z pliku
	shl eax, 2                  ;zwiększenie adresu z bajtu do 4 bajtów     
	mov dword [index], 12          ;index wskazuje na pierwszy znak w array (czyli na roota)
	mov dword [codeLen], 0      ;długość kodu dla bieżącego znaku
	
findCharInArray:
	mov dword [temp1], edi 
	mov edi, dword [index]
	lea ebx, [array + edi]
	mov ecx, dword [ebx]              ;znak z bieżącego węzła z drzewa
	mov edx, dword [index]                ;indeks węzła nakierowany na znak
	sub edx, 12               ;indeks węzła (nakierowany na początek węzła)
	mov edi, dword [temp1]
	cmp ecx, eax
	je getCharCode              ;znaleziono węzeł drzewa odpowiadający poszukiwanemu znakowi  
	add dword [index], 20
	jmp findCharInArray	

getCharCode:
	add dword [index], 4                ;wskazuje na rodzica znaku znalezionego w array
	mov dword [temp1], edi 
	mov dword [temp2], esi 
	mov esi, dword [index]
	lea ebx, [array + esi]
	mov eax, dword [ebx]              ;indeks rodzica
	add eax, 4                ;wskazuje na lewego syna rodzica
	lea ebx, [array + eax]
	mov ebx, [ebx]                ;indeks lewego syna rodzica
	mov edi, dword [codeLen]              ;bieżący adres do zapisu do byteBufferForCode      
	inc dword [codeLen]                     ;inkrementacja długości kodu dla bieżącego znaku   
	lea edi, [byteBufferForCode + edi]
	cmp edx, ebx
	je writeOne   ;węzeł był lewym synem rodzica, trzeba napisać '1' do bufora 'arrayWithCode'

;węzeł był prawym synem rodzica, trzeba napisać '0' do bufora 'arrayWithCode'	
writeZero:
	mov byte [edi], 0                ;zapisanie '0' do byteBufferForCode
	jmp continueGetCharCode	

writeOne:
	mov byte [edi], 1              ;zapisanie '1' do byteBufferForCode

continueGetCharCode:
	mov edi, dword [temp1]
	mov esi, dword [temp2]
	mov dword [temp1], edi 
	mov edi, dword [index]
	lea ebx, [array + edi]
	mov eax, dword [ebx]         ;indeks rodzica poprzedniego	
	mov edx, eax              ;poprzedni rodzic to teraz bieżący węzeł (idziemy od liścia do 
							  ;korzenia w górę drzewa) - chodzi o adres w tablicy
    mov dword [index], eax		
	mov edi, dword [temp1] 				
	cmp eax, 0            ;jeśli bieżący węzeł jest rootem to mamy już cały kod dla tego znaku
	je orderByteBufferForCode
	add dword [index], 12
	jmp getCharCode	

;w tym momencie mamy byteBufferForCode czyli bufor przechowujący kod bieżącego znaku (idąc od liścia 
;do korzenia, a więc na odwrót niż chcemy, dlatego trzeba odwrócić kolejność bajtów w tym buforze)
orderByteBufferForCode:
	mov dword [index1ForCode], 0   ;adres pierwszego znaczącego elementu w byteBufferForCode
	mov ebx, dword [codeLen]           
	sub ebx, 1
	mov dword [index2ForCode], ebx   ;adres ostatniego znaczącego elementu w byteBufferForCode

loopForOrderByteBufferForCode:
	mov ebx, dword [index2ForCode]
	cmp dword [index1ForCode], ebx
	jge writeToCode     ;kod znaku w byteBufferForCode już jest właściwy, tylko teraz trzeba 
	                    ;go zapisać do bufora bitowego (czyli do 'arrayWithCode')
	
	mov dword [temp1], eax
	mov dword [temp2], ebx
	xor eax, eax                 
	xor ebx, ebx                
	mov dword [temp3], ecx
	mov ecx, dword [index1ForCode]
	lea edi, [byteBufferForCode + ecx]
	mov al, byte [edi]
	mov ecx, dword [index2ForCode]
	lea esi, [byteBufferForCode + ecx]
	mov bl, byte [esi]
	mov byte [edi], bl
	mov byte [esi], al
	mov eax, dword [temp1]
	mov ebx, dword [temp2]
	mov ecx, dword [temp3]

	inc dword [index1ForCode]
	dec dword [index2ForCode]
	jmp loopForOrderByteBufferForCode

writeToCode:	
	mov dword [index1ForCode], 0     ;index bieżącego elementu z byteBufferForCode 
	                                 ;(odpowiadający bieżącemu bitowi znaku)
	mov dword [bytesCounter], 0
	mov dword [indexForCode], 0      ;adres dla bufora 'arrayWithCode'
	mov edi, dword [codeLen]
	cmp dword [index1ForCode], edi
	jge writeCodeForCharToFile2      ;przejrzano cały bufor byteBufferForCode (ostatni bieżący, 
		                             ;niepełny bajt pozostał w rejestrze bieżącego bajtu) 

loopForWriteToCode:
	mov dword [temp1], eax
	mov dword [temp2], ebx
	mov ebx, dword [index1ForCode]
	lea edi, [byteBufferForCode + ebx]
	mov al, byte [edi]
	mov esi, eax
	mov eax, dword [temp1]
	mov ebx, dword [temp2]
	cmp esi, 1
	je writeBiteOne
	
writeBiteZero:
	inc dword [index1ForCode]            ;zwiększenie indexu dla byteBufferForCode
	inc dword [bitsInCurrByteCode]         ;zwiększenie ilości bitów w bieżącym bajcie kodu 
	cmp dword [bitsInCurrByteCode], 8
	je writeByteToCode
	
	mov esi, dword [mask]
	shr esi, 1   ;przesunięcie bitu '1' o 1 w prawo w masce do zapisu kodu dla bieżącego bajtu
	mov dword [mask], esi
	mov edi, dword [codeLen]
	cmp dword [index1ForCode], edi
	jge writeCodeForCharToFile2      ;przejrzano cały bufor byteBufferForCode (ostatni bieżący, 
		                             ;niepełny bajt pozostał w rejestrze bieżącego bajtu) 
	jmp loopForWriteToCode

writeBiteOne:
	mov edi, dword [currByteCode]
	mov esi, dword [mask]
	or edi, esi                      ;zapisanie bitu '1' do bieżącego bajtu kodu
	mov dword [currByteCode], edi
	
	inc dword [index1ForCode]              ;zwiększenie indexu dla byteBufferForCode
	inc dword [bitsInCurrByteCode]           ;zwiększenie ilości bitów w bieżącym bajcie kodu 
	cmp dword [bitsInCurrByteCode], 8
	je writeByteToCode   ;jeśli mamy już cały bajt bieżącego kodu

	shr esi, 1   ;przesunięcie bitu '1' o 1 w prawo w masce do zapisu kodu dla bieżącego bajtu
	mov dword [mask], esi
	mov edi, dword [codeLen]
	cmp dword [index1ForCode], edi
	jge writeCodeForCharToFile2      ;przejrzano cały bufor byteBufferForCode (ostatni bieżący, 
		                             ;niepełny bajt pozostał w rejestrze bieżącego bajtu) 
	jmp loopForWriteToCode
	
writeByteToCode:
	inc dword [bytesCounter]      ;inkrementacja licznika pełnych bajtów kodu bieżacego znaku
	mov dword [temp1], eax
	mov dword [temp2], ebx
	mov ebx, dword [indexForCode]
	mov eax, dword [currByteCode]
	lea edi, [arrayWithCode + ebx]
	mov ebx, dword [temp2]
	mov byte [edi], al               ;zapisanie bieżącego bajtu kodu do bufora 'arrayWithCode' 
	inc dword [indexForCode]            ;zwiększenie indexu dla bufora 'arrayWithCode'	
	mov dword [currByteCode], 0      ;wyzerowanie licznika bitów w bieżącym bajcie kodu
	mov dword [bitsInCurrByteCode], 0   ;wyzerowanie bieżącego bajtu kodu dla bieżącego znaku
	mov dword [mask], 128            ;ustawienie maski (ponownie na 10000000)
	mov eax, dword [temp1]
	mov edi, dword [codeLen]
	cmp dword [index1ForCode], edi
	jge writeCodeForCharToFile2      ;przejrzano cały bufor byteBufferForCode (ostatni bieżący, 
		                             ;niepełny bajt pozostał w rejestrze bieżącego bajtu) 
	jmp loopForWriteToCode  ;powrót do czytania z 'byteBufferForCode' i uzupełniania bieżącego
	                        ;bajtu dla kodu bieżącego znaku
						
;w buforze 'arrayWithCode' mamy kod dla bieżącego znaku, teraz trzeba go zapisać do pliku file2					
writeCodeForCharToFile2:
	mov dword [indexForCode], 0
	cmp dword [bytesCounter], 0
	je readFile2Loop  ;zapisano już wszystkie pełne bajty kodu bieżącego znaku do pliku file2,
				      ;należy wczytać kolejny znak z pliku fileName w celu zakodowania 

loopToWriteByteToFile2:
	mov dword [temp1], ebx
	mov ebx, dword [indexForCode]
	lea edi, [arrayWithCode + ebx]
	mov ebx, dword [temp1]
	mov al,byte [edi] 
	mov byte [buffer], al 

	mov eax, 4                  ;zapis do pliku kodowanego
	mov ebx, dword [file2]      
	mov ecx, buffer          
	mov edx, 1                 
	int 0x80

	inc dword [indexForCode]      ;inkrementacja indexu dla 'arrayWithCode'
	dec dword [bytesCounter]    ;dekrementacja licznika pełnych bajtów kodu dla bieżącego znaku
	cmp dword [bytesCounter], 0
	je readFile2Loop  ;zapisano już wszystkie pełne bajty kodu bieżącego znaku do pliku file2,
				      ;należy wczytać kolejny znak z pliku fileName w celu zakodowania 
	jmp loopToWriteByteToFile2

handleLastCurrentByteOfCode:
	mov edi, arrayWithCode
	mov eax, dword [currByteCode]
	mov byte [edi], al 
	
	mov eax, 4                 ;zapis do pliku kodowanego                                                      
	mov ebx, dword [file2]     
	mov ecx, arrayWithCode     ;ostatni bieżący bajt kodu jest zapisywany do pliku kodowanego
	mov edx, 1
	int 0x80

;zapisanie do pliku ilości znaczących bitów w ostatnim bajcie zakodowanego tekstu	
	mov al, byte [bitsInCurrByteCode]
	mov byte [buffer], al  
	
	mov eax, 4              ;zapis do pliku kodowanego
	mov ebx, [file2]       
	mov ecx, buffer
	mov edx, 1
	int 0x80

;zamknięcie otwartych plików
	mov eax, 6          ;zamknięcie pliku
	mov ebx, [file1]  ;deskryptor pliku niezakodowanego
	int 0x80

	mov eax, 6          ;zamknięcie pliku
	mov ebx, [file2]  ;deskryptor pliku zakodowanego
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