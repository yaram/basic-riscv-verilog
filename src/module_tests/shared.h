#pragma once

#include "verilated.h"

static inline CData get_bit(CData data, CData index) {
    return (data >> index) & 1;
}

static inline SData get_bit(SData data, SData index) {
    return (data >> index) & 1;
}

static inline IData get_bit(IData data, IData index) {
    return (data >> index) & 1;
}

static inline QData get_bit(QData data, QData index) {
    return (data >> index) & 1;
}

static inline void set_bit(CData *data, CData index) {
    *data |= 1 << index;
}

static inline void set_bit(SData *data, SData index) {
    *data |= 1 << index;
}

static inline void set_bit(IData *data, IData index) {
    *data |= 1 << index;
}

static inline void set_bit(QData *data, QData index) {
    *data |= 1 << index;
}

static inline void unset_bit(CData *data, CData index) {
    *data &= ~(1 << index);
}

static inline void unset_bit(SData *data, SData index) {
    *data &= ~(1 << index);
}

static inline void unset_bit(IData *data, IData index) {
    *data &= ~(1 << index);
}

static inline void unset_bit(QData *data, QData index) {
    *data &= ~(1 << index);
}

static inline CData bit_mask(CData length) {
    return (CData)-1 >> ((CData)sizeof(CData) * 8 - length);
}

static inline SData bit_mask(SData length) {
    return (SData)-1 >> ((SData)sizeof(SData) * 8 - length);
}

static inline IData bit_mask(IData length) {
    return (IData)-1 >> ((IData)sizeof(IData) * 8 - length);
}

static inline QData bit_mask(QData length) {
    return (QData)-1 >> ((QData)sizeof(QData) * 8 - length);
}

static inline CData get_sub_bits(CData data, CData index, CData length) {
    return (data >> index) & bit_mask(length);
}

static inline SData get_sub_bits(SData data, SData index, SData length) {
    return (data >> index) & bit_mask(length);
}

static inline IData get_sub_bits(IData data, IData index, IData length) {
    return (data >> index) & bit_mask(length);
}

static inline QData get_sub_bits(QData data, QData index, QData length) {
    return (data >> index) & bit_mask(length);
}

static inline void set_sub_bits(CData *data, CData index, CData length, CData bits) {
    auto mask = bit_mask(length);

    *data &= ~(mask << index);
    *data |= (bits & mask) << index;
}

static inline void set_sub_bits(SData *data, SData index, SData length, SData bits) {
    auto mask = bit_mask(length);

    *data &= ~(mask << index);
    *data |= (bits & mask) << index;
}

static inline void set_sub_bits(IData *data, IData index, IData length, IData bits) {
    auto mask = bit_mask(length);

    *data &= ~(mask << index);
    *data |= (bits & mask) << index;
}

static inline void set_sub_bits(QData *data, QData index, QData length, QData bits) {
    auto mask = bit_mask(length);

    *data &= ~(mask << index);
    *data |= (bits & mask) << index;
}

static inline void reverse_bit_order(CData *data) {
    auto bit_length = (CData)sizeof(CData) * 8;

    auto old_data = *data;
    *data = 0;

    for(CData i = 0; i < bit_length; i += 1) {
        *data |= ((old_data >> (bit_length - i - 1)) & 1) << i;
    }
}

static inline void reverse_bit_order(SData *data) {
    auto bit_length = (SData)sizeof(SData) * 8;

    auto old_data = *data;
    *data = 0;

    for(SData i = 0; i < bit_length; i += 1) {
        *data |= ((old_data >> (bit_length - i - 1)) & 1) << i;
    }
}

static inline void reverse_bit_order(IData *data) {
    auto bit_length = (IData)sizeof(IData) * 8;

    auto old_data = *data;
    *data = 0;

    for(IData i = 0; i < bit_length; i += 1) {
        *data |= ((old_data >> (bit_length - i - 1)) & 1) << i;
    }
}

static inline void reverse_bit_order(QData *data) {
    auto bit_length = (QData)sizeof(QData) * 8;

    auto old_data = *data;
    *data = 0;

    for(QData i = 0; i < bit_length; i += 1) {
        *data |= ((old_data >> (bit_length - i - 1)) & 1) << i;
    }
}