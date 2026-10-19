# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name DirNoise
extends RefCounted
## One small tiling noise texture made at startup with the engine's FastNoiseLite (native, a
## few milliseconds). The wood shader samples it for warp, figure, fibers and pores, which is
## much cheaper on a phone than computing noise per pixel.

static var _texture: ImageTexture


static func texture() -> ImageTexture:
	if _texture == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.seed = 7
		noise.frequency = 0.03
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = 3
		var image := noise.get_seamless_image(256, 256, false, false, 0.1, true)
		image.convert(Image.FORMAT_L8)
		image.generate_mipmaps()
		_texture = ImageTexture.create_from_image(image)
	return _texture
