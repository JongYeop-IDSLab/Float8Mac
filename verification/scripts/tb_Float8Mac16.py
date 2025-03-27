import numpy as np
import torch 

# Function to initialize random data in float8 format
def init_float8(shape):
    # 1-4-3 format
    return torch.randn(shape).to(torch.float8_e4m3fn)

# Convert pytorch float8 array to uint8 array
def float8arr_to_uint8_arr(nparr, endian='little'):
    if nparr.dtype != torch.float8_e4m3fn:
        raise ValueError('float8arr_to_uint8_arr: nparr must be of type float8_e4m3fn')
    if nparr.ndim != 1:
        nparr = nparr.reshape(-1)
    uint8_list = []
    # Since float8 does not offer bitwise operation, we need to convert to int16 first
    nparr = nparr.view(torch.int8)
    for elem in nparr:
        if endian == 'little':
            uint8_list.append(elem & 0xFF)
            # uint8_list.append((elem >> 8) & 0xFF)
        elif endian == 'big':
            uint8_list.append((elem >> 8) & 0xFF)
            uint8_list.append(elem & 0xFF)
        else:
            raise ValueError('float8arr_to_uint8_arr: endian must be either little or big')
    nparr = np.array(uint8_list, dtype=np.uint8)
    return nparr

# Convert pytorch float16 array to uint8 array
def bfloat16arr_to_uint8_arr(nparr, endian='little'):
    if nparr.dtype != torch.bfloat16:
        raise ValueError('bfloat8arr_to_uint8_arr: nparr must be of type bfloat16')
    if nparr.ndim != 1:
        nparr = nparr.reshape(-1)
    uint8_list = []
    # Since float8 does not offer bitwise operation, we need to convert to int16 first
    nparr = nparr.view(torch.int16)
    for elem in nparr:
        if endian == 'little':
            uint8_list.append(elem & 0xFF)
            uint8_list.append((elem >> 8) & 0xFF)
        elif endian == 'big':
            uint8_list.append((elem >> 8) & 0xFF)
            uint8_list.append(elem & 0xFF)
        else:
            raise ValueError('float8arr_to_uint8_arr: endian must be either little or big')
    nparr = np.array(uint8_list, dtype=np.uint8)
    return nparr

if __name__ == '__main__':
    # This file should be called by the Makefile in the root directory
    # This file creates appropriate test data, puts it into ./verification/hex/input/tb_FP_Adder_16_2stage.hex
    N_TEST = 10000
    # Generate random test data
    x = init_float8((N_TEST, 16))
    x_fp32 = x.float()
    w = init_float8((N_TEST, 16))
    w_fp32 = w.float()
    x_uint8 = float8arr_to_uint8_arr(x).reshape(N_TEST*16,1)
    w_uint8 = float8arr_to_uint8_arr(w).reshape(N_TEST*16,1)
    ref = torch.sum(x_fp32 * w_fp32, dim=1).reshape(N_TEST,1)
    ref_bf16 = ref.bfloat16()
    ref_uint8 = bfloat16arr_to_uint8_arr(ref_bf16)
    ref_uint16 = ref_uint8.reshape(-1, 2).view(np.uint16)

    with open('./verification/hex/input/tb_Float8Mac_X.hex', 'w') as f:
        for row in x_uint8:
            f.write(' '.join(format(val, 'X') for val in row) + '\n')
    
    with open('./verification/hex/input/tb_Float8Mac_W.hex', 'w') as f:
        for row in w_uint8:
            f.write(' '.join(format(val, 'X') for val in row) + '\n')
    
    with open('./verification/hex/ref/tb_Float8Mac.hex', 'w') as f:
        for row in ref_uint16:
            f.write(' '.join(format(val, 'X') for val in row) + '\n')
