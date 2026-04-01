/*
 * neg_vla.c — C99 Variable-Length Arrays (VLA)
 * EXPECT: compile FAIL
 *
 * ORCA/C defines __STDC_NO_VLA__ — VLAs are not supported.
 * This file should fail to compile with an error about VLA.
 */

int make_vla(int n) {
    int arr[n];     /* VLA — not supported by ORCA/C */
    arr[0] = n;
    return arr[0];
}
