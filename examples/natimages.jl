
using MAT
import Nettle

images_url = "http://www.rctn.org/bruno/sparsenet/IMAGES.mat"
images_file = "$(@__DIR__)/IMAGES.mat"
images_md5 = "b20cb33935e95b556cb83bef5e9afcf1"


file_ok = false

if isfile(images_file)
    h = Nettle.Hasher("md5")
    Nettle.update!(h, read(images_file))
    if Nettle.hexdigest!(h) == images_md5
        file_ok = true
    end
end

if !file_ok
    println("Downloading $images_url")
    download(images_url, images_file)
end


function nat_images()
    f = matopen(images_file)
    read(f, "IMAGES")
end


