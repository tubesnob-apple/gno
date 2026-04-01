/*
 * t_digraphs.c — C99 digraphs and %: trigraph-free alternative tokens
 * EXPECT: compile success
 */

/* Digraph equivalents:
 *   <: == [    :> == ]
 *   <% == {    %> == }
 *   %: == #
 */

%:include <stddef.h>

int arr<:10:>;          /* int arr[10]; */

int test_digraphs(void) <%  /* { */
    int x<:5:> = <%1, 2, 3, 4, 5%>;  /* int x[5] = {1,2,3,4,5}; */
    return (x<:0:> == 1) ? 0 : 1;
%>                      /* } */
