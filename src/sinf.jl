const DP1 = 0.78515625f0
const DP2 = 2.4187564849853515625f-4
const DP3 = 3.77489497744594108f-8
const lossth = 8192.0f0
const T24M1 = 16777215.0f0

const sincof1 = -1.9515295891f-4
const sincof2 =  8.3321608736f-3
const sincof3 = -1.6666654611f-1

const coscof1 =  2.443315711809948f-5
const coscof2 = -1.388731625493765f-3
const coscof3 =  4.166664568298827f-2

const FOPI = 1.27323954473516f0


function sinf(xx::Float32)
    x = abs(xx)
    sign = ifelse(xx<0, -one(xx), one(xx))
    if (x > T24M1)
        return zero(x)
    end
    j = trunc(UInt32, FOPI * x)
    y = Float32(j)
    y += j & 1
    j += j & 1
    j &= 7
    if (j > 3)
        sign = -sign
        j -= 4
    end
    if (x > lossth)
        x = x - y * PIO4F
    else
        x = ((x - y * DP1) - y * DP2) - y * DP3
    end
    z = x * x
    if (j==1) || (j==2)
        y = coscof1
        y = y * z + coscof2
        y = y * z + coscof3
        y *= z * z
        y -= 0.5 * z
        y += 1.0
    else
        y = sincof1
        y = y * z + sincof2
        y = y * z + sincof3
        y *= z * z
        y += x
    end
    if (sign < 0)
        y = -y
    end
    return y
end

sinf(0.0f0)