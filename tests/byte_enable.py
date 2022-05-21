def byte_enable (address, data, strobe):
    scale = 10 
    num_of_bits = 64
    data_bin = list(bin(int(data))[2:].zfill(num_of_bits))
    strb_bin = list(bin(int(strobe))[2:].zfill(8))
    for strb_index in range (8):
        for data_index in range (8):
            if strb_bin[strb_index] == '0':
                data_bin[(8*strb_index) + data_index] = 0
            else:
                if data_bin[(8*strb_index) + data_index] == '1':
                    data_bin[(8*strb_index) + data_index] = 1
                else:
                    data_bin[(8*strb_index) + data_index] = 0
   
    return binatodeci(data_bin) >> ((address % 8)*8) # need shift for data alighment purpose

def binatodeci(binary):
    return sum(val*(2**idx) for idx, val in enumerate(reversed(binary))) 
