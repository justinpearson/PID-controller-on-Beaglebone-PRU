#include <stdio.h> // atof
#include <stdlib.h> // atof
#include <math.h> // pow, sin

#include "util-jpp.h"

int main(int argc, char* argv[] ) {

  printf("%s (%d): Got %d args:\n",__FUNCTION__,__LINE__,argc);
  for( int i=0; i<argc; i++ ) {
    printf("Arg %d: %s\n",i,argv[i]);
  }

  double duration = atof(argv[1]);

  printf("%s %s (%d): Burn CPU for %lf sec.\n",__FILE__,__FUNCTION__,__LINE__,duration);
  double cputimediff;
  double t0;
  double x = 0;
  long long int iters = 0;
      toc(&t0, &cputimediff);

      while(1) {
	for( int i=0; i<100; i++ ) {
	  x += pow(sin(M_PI * .001 * i),10);
	  iters += 1;
	}
	double t1;
	toc(&t1, &cputimediff);
	if( t1-t0 > duration ) break;
      }
      printf("%s %s: End (%lld iters).\n",__FILE__,__FUNCTION__,iters);
  return 0;
}
