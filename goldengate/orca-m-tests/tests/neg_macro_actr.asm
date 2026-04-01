******************************************************************
* neg_macro_actr.asm   — EXPECTED TO FAIL ASSEMBLY
*
* RECURSE is an infinitely recursive macro with no exit condition.
* The default ACTR limit stops expansion after a bounded number of
* iterations and terminates with an error rather than hanging.
*
* With +T (terminal on first error), assembly must fail with a
* non-zero exit code.
*
* Macro defined in neg_macro_actr.mac.
******************************************************************
         MCOPY neg_macro_actr.mac
         LONGA OFF
         LONGI OFF

TEST     START

         RECURSE

         END
