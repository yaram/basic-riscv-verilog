#define RVTEST_RV32U

#define RVTEST_CODE_BEGIN li x31, 0
#define RVTEST_CODE_END RVTEST_FAIL

#define RVTEST_DATA_BEGIN
#define RVTEST_DATA_END

#define RVTEST_PASS \
    li t0, 0xFFFFFD; \
    sb x31, (t0)

#define RVTEST_FAIL \
    li t0, 0xFFFFFE; \
    sb x31, (t0)