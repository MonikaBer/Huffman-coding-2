#include <stdio.h>
#ifdef _Cplusplus
extern "C" {
#endif

int code(char *input, char *output);
int decode(char *input, char *output);
#ifdef _Cplusplus
}
#endif


int main(int argc, char** argv)
{ 
  if ( argc < 4 || (*argv[1] != '0' && *argv[1] != '1') ) {
      printf("Usage: ./main <0/1> <input> <output>\n0 - code\n1 - decode\n\n");
      return 1;
  }
  
  if (*argv[1] == '0') {
      code(argv[2], argv[3]);
  } else if(*argv[1] == '1') {
      decode(argv[2], argv[3]);
  }

  return 0;
}
