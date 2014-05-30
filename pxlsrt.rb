require 'rubygems'
require 'oily_png'
require 'thor'

class ChunkyPNG::Image
	def at(x,y)
		ChunkyPNG::Color.to_grayscale_bytes(self[x,y]).first
	end
end

def contented(c)
	return (((defined? c)!="nil") && ((/(\S)/.match("#{c}"))!=nil))
end

def arrayToRGB(a)
	return ChunkyPNG::Color.rgb(a[0], a[1], a[2])
end

def getRGB(pxl)
	return [ChunkyPNG::Color.r(pxl), ChunkyPNG::Color.g(pxl), ChunkyPNG::Color.b(pxl)]
end

def pxldex(pxl)
	return pxl[0]+pxl[1]+pxl[2]
end

def rgb2hsb(rgb)
	r = rgb[0] / 255.0
	g = rgb[1] / 255.0
	b = rgb[2] / 255.0
	max = [r, g, b].max
	min = [r, g, b].min
	delta = max - min
	v = max * 100
	 
	if (max != 0.0)
		s = delta / max *100
	else
		s = 0.0
	end
	 
	if (s == 0.0) 
		h = 0.0
	else
		if (r == max)
			h = (g - b) / delta
		elsif (g == max)
			h = 2 + (b - r) / delta
		elsif (b == max)
			h = 4 + (r - g) / delta
		end
	 
		h *= 60.0
		
		if (h < 0)
			h += 360.0
		end
	end
	return [h,s,v]
end

def pixelSort(list, how, reverse)
	mhm=[]
	case how.downcase
		when "sum-rgb"
			mhm= list.sort_by { |c| pxldex(c) }
		when "red"
			mhm= list.sort_by { |c| c[0] }
		when "green"
			mhm= list.sort_by { |c| c[1] }
		when "blue"
			mhm= list.sort_by { |c| c[2] }
		when "hue"
			mhm= list.sort_by { |c| rgb2hsb(c)[0] }
		when "saturation"
			mhm= list.sort_by { |c| rgb2hsb(c)[1] }
		when "brightness"
			mhm= list.sort_by { |c| rgb2hsb(c)[2] }
		when "sum-hsb"
			mhm= list.sort_by { |c| k=rgb2hsb(c); k[0]*100/360+k[1]+k[2] }
		when "uniqueness"
			avg=colorAverage(list)
			mhm=list.sort_by { |c| colorUniqueness(c, [avg]) }
		when "luma"
			mhm=list.sort_by { |c| pxldex([c[0]*0.2126, c[1]*0.7152, c[2]*0.0722]) }
		when "random"
			mhm=list.shuffle
		else
			mhm= list.sort_by { |c| pxldex(c) }
	end
	if reverse == 0
		return mhm
	elsif reverse == 1
		return mhm.reverse
	else
		return rand(0..1)==0 ? mhm : mhm.reverse
	end
end

def imageRGBLines(image, width)
	return image.each_slice(width).to_a
end

def getDiagonals(array, width, height)
	dias={}
	for x in (1-height)..(width-1)
		z=[]
		for y in 0..(height-1)
			if (x+(width+1)*y).between?(width*y, (width*(y+1)-1))
				z.push(array[(x+(width+1)*y)])
			end
		end
		dias[x.to_s]=z
	end
	return dias
end

def fromDiagonals(obj, width)
	ell=[]
	for k in obj.keys
		r=k.to_i
		n=r < 0
		if n
			x=0
			y=r.abs
		else
			x=r
			y=0
		end
		ell[x+y*width]=obj[k].first
		for v in 1..(obj[k].length-1)
			x+=1
			y+=1
			ell[x+y*width]=obj[k][v]
		end
	end
	return ell
end

def randomSlices(arr, minLength, maxLength)
	len=arr.length-1
	if len!=0
		min=[minLength, maxLength].min
		max=[maxLength, minLength].max
		if min > len
			min=len
		end
		if max > len
			max=len
		end
		nu=[[0, rand(min..max)]]
		last=nu.first[1]
		sorting=true
		while sorting do
			if (len-last) <= max
				nu.push([last+1, len])
				sorting=false
			else
				nu.push([last+1, last+1+rand(min..max)])
				last=nu.last[1]
			end
		end
	else
		nu=[[0,0]]
	end
	return nu
end

def colorDistance(c1,c2)
	return Math.sqrt((c1[0]-c2[0])**2+(c1[1]-c2[1])**2+(c1[2]-c2[2])**2)
end

def colorAverage(ca)
	if ca.length==1
		return ca.first
	end
	r=((ca.collect { |c| c[0] }).inject{ |sum, el| sum+el }).to_f / ca.size
	g=((ca.collect { |c| c[1] }).inject{ |sum, el| sum+el }).to_f / ca.size
	b=((ca.collect { |c| c[2] }).inject{ |sum, el| sum+el }).to_f / ca.size
	return [r,g,b]
end

def colorUniqueness(c, ca)
	return colorDistance(c, colorAverage(ca))
end

class PXLSRT < Thor
	class_option :reverse, :type => :string, :default => "no", :banner => "[no | reverse | either]", :aliases => "-r", :enum => ["no", "reverse", "either"]
	class_option :vertical, :type => :boolean, :default => false, :aliases => "-v"
	class_option :diagonal, :type => :boolean, :default => false, :aliases => "-d"
	class_option :smooth, :type => :boolean, :default => false, :aliases => "-s"
	class_option :method, :type => :string, :default => "sum-rgb", :banner => "[sum-rgb | red | green | blue | sum-hsb | hue | saturation | brightness | uniqueness | luma | random]", :aliases => "-m", :enum => ["sum-rgb", "red", "green", "blue", "sum-hsb", "hue", "saturation", "brightness", "uniqueness", "luma", "random"]
	class_option :diagonal, :type => :boolean, :default => false, :aliases => "-d"

	option :min, :type => :numeric, :required => true, :banner => "MINIMUM BANDWIDTH"
	option :max, :type => :numeric, :required => true, :banner => "MAXIMUM BANDWIDTH"
	desc "brute INPUT OUTPUT [options]", "Brute pixel sorting"
	def brute(input, output)
		case options[:reverse].downcase
			when "reverse"
				nre=1
			when "either"
				nre=-1
			else
				nre=0
		end
		png=ChunkyPNG::Image.from_file(input)
		if options[:vertical]==true
			png=png.rotate_left
		end
		w=png.dimension.width
		h=png.dimension.height
		sorted=ChunkyPNG::Image.new(w, h, ChunkyPNG::Color::TRANSPARENT)
		kml=[]
		for xy in 0..(w*h-1)
			kml.push(getRGB(png[xy % w,(xy/w).floor]))
		end
		toImage=[]
		if !options[:diagonal]
			for m in imageRGBLines(kml, w)
				sliceRanges=randomSlices(m, options[:min], options[:max])
				#puts sliceRanges.last.last
				newInTown=[]
				if options[:smooth]==true
					for ranger in sliceRanges
						newInTown.concat(pixelSort(m[ranger[0]..ranger[1]], options[:method].downcase, nre))
					end
				else
					for ranger in sliceRanges
						k=(m[ranger[0]..ranger[1]]).group_by { |x| x }
						g=pixelSort(k.keys, options[:method].downcase, nre)
						j=g.map { |x| k[x] }.flatten(1)
						newInTown.concat(j)
					end
				end
				toImage.concat(newInTown)
			end
		else
			dia=getDiagonals(kml,w,h)
			for m in dia.keys
				sliceRanges=randomSlices(dia[m], options[:min], options[:max])
				newInTown=[]
				if options[:smooth]==true
					for ranger in sliceRanges
						newInTown.concat(pixelSort(dia[m][ranger[0]..ranger[1]], options[:method].downcase, nre))
					end
				else
					for ranger in sliceRanges
						k=(dia[m][ranger[0]..ranger[1]]).group_by { |x| x }
						g=pixelSort(k.keys, options[:method].downcase, nre)
						j=g.map { |x| k[x] }.flatten(1)
						newInTown.concat(j)
					end
				end
				dia[m]=newInTown
			end
			toImage=fromDiagonals(dia,w)
		end
		for xy in 0..(w*h-1)
			sorted[xy % w, (xy/w).floor]=arrayToRGB(toImage[xy])
		end
		if options[:vertical]==true
			sorted=sorted.rotate_right
		end
		sorted.save(output)
	end

	option :absolute, :type => :boolean, :default => false, :aliases => "-a", :banner => "ABSOLUTE EDGE FINDING"
	option :threshold, :type => :numeric, :required => true, :aliases => "-t"
	option :edge, :type => :numeric, :default => 2, :aliases => "-e", :banner => "EDGE BUFFERING"
	desc "smart INPUT OUTPUT [options]", "Smart pixel sorting"
	def smart(input, output)
		case options[:reverse].downcase
			when "reverse"
				nre=1
			when "either"
				nre=-1
			else
				nre=0
		end
		img = ChunkyPNG::Image.from_file(input)
		if options[:vertical]==true
			img=img.rotate_left
		end
		sobel_x = [[-1,0,1], [-2,0,2], [-1,0,1]]
		sobel_y = [[-1,-2,-1], [ 0, 0, 0], [ 1, 2, 1]]
		edge = ChunkyPNG::Image.new(img.width, img.height, ChunkyPNG::Color::TRANSPARENT)
		k=[]
		for xy in 0..(img.width*img.height-1)
			x=xy % img.width
			y=(xy/img.width).floor
			if x!=0 and x!=(img.width-1) and y!=0 and y!=(img.height-1)
				pixel_x=(sobel_x[0][0]*img.at(x-1,y-1))+(sobel_x[0][1]*img.at(x,y-1))+(sobel_x[0][2]*img.at(x+1,y-1))+(sobel_x[1][0]*img.at(x-1,y))+(sobel_x[1][1]*img.at(x,y))+(sobel_x[1][2]*img.at(x+1,y))+(sobel_x[2][0]*img.at(x-1,y+1))+(sobel_x[2][1]*img.at(x,y+1))+(sobel_x[2][2]*img.at(x+1,y+1))
				pixel_y=(sobel_y[0][0]*img.at(x-1,y-1))+(sobel_y[0][1]*img.at(x,y-1))+(sobel_y[0][2]*img.at(x+1,y-1))+(sobel_y[1][0]*img.at(x-1,y))+(sobel_y[1][1]*img.at(x,y))+(sobel_y[1][2]*img.at(x+1,y))+(sobel_y[2][0]*img.at(x-1,y+1))+(sobel_y[2][1]*img.at(x,y+1))+(sobel_y[2][2]*img.at(x+1,y+1))
				val = Math.sqrt(pixel_x * pixel_x + pixel_y * pixel_y).ceil
			else
				val = Float::INFINITY
			end
			k.push({ "sobel" => val, "pixel" => [x, y], "color" => getRGB(img[x, y]) })
		end

		if !options[:diagonal]
			lines=imageRGBLines(k, img.width)
			bands=Array.new()
			for j in lines
				slicing=true
				pixel=0
				m=Array.new()
				while slicing do
					n=Array.new
					if m.length > 1
						while m.last.length < options[:edge]
							if m.length > 1
								m[-2].concat(m[-1])
								m.pop
							else
								break
							end
						end
					end
					bandWorking=true
					while bandWorking do
						n.push(j[pixel]["color"])
						if (options[:absolute] ? (j[pixel+1]["sobel"]) : (j[pixel+1]["sobel"]-j[pixel]["sobel"])) > options[:threshold]
							bandWorking=false
						end
						if (pixel+1)==(j.length-1)
							n.push(j[pixel+1]["color"])
							slicing=false
							bandWorking=false
						end
						pixel+=1
					end
					m.push(n)
				end
				bands.concat(m)
			end
			image=[]
			if options[:smooth]
				for band in bands
					u=band.group_by {|x| x}
					image.concat(pixelSort(u.keys, options[:method], nre).map { |x| u[x] }.flatten(1))
				end
			else
				for band in bands
					image.concat(pixelSort(band, options[:method], nre))
				end
			end
		else
			dia=getDiagonals(k,img.width,img.height)
			for j in dia.keys
				bands=[]
				if dia[j].length>1
					slicing=true
					pixel=0
					m=Array.new()
					while slicing do
						n=Array.new
						if m.length > 1
							while m.last.length < options[:edge]
								if m.length > 1
									m[-2].concat(m[-1])
									m.pop
								else
									break
								end
							end
						end
						bandWorking=true
						while bandWorking do
							n.push(dia[j][pixel]["color"])
							if (options[:absolute] ? (dia[j][pixel+1]["sobel"]) : (dia[j][pixel+1]["sobel"]-dia[j][pixel]["sobel"])) > options[:threshold]
								bandWorking=false
							end
							if (pixel+1)==(dia[j].length-1)
								n.push(dia[j][pixel+1]["color"])
								slicing=false
								bandWorking=false
							end
							pixel+=1
						end
						m.push(n)
					end
				else
					m=[[dia[j].first["color"]]]
				end
				dia[j]=bands.concat(m)
			end
			for j in dia.keys
				ell=[]
				if options[:smooth]
					for band in dia[j]
						u=band.group_by {|x| x}
						ell.concat(pixelSort(u.keys, options[:method], nre).map { |x| u[x] }.flatten(1))
					end
				else
					for band in dia[j]
						#puts band.first
						ell.concat(pixelSort(band, options[:method], nre))
					end
				end
				dia[j]=ell
			end
			image=fromDiagonals(dia,img.width)
		end
		for px in 0..(img.width*img.height-1)
			edge[px % img.width, (px/img.width).floor]=arrayToRGB(image[px])
		end
		if options[:vertical]==true
			edge=edge.rotate_right
		end
		edge.save(output)
	end
end

PXLSRT.start(ARGV)