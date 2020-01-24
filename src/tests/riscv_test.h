#define RVTEST_RV32U

#define RVTEST_CODE_BEGIN
#define RVTEST_CODE_END RVTEST_FAIL

#define RVTEST_DATA_BEGIN
#define RVTEST_DATA_END

#define RVTEST_PASS \
    li t0, 0xFFFFFD; \
    sb zero, (t0)

#define RVTEST_FAIL \
    li t0, 0xFFFFFE; \
    sb zero, (t0)