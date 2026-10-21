# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name WoodNoise
extends RefCounted
## The one small tiling noise texture the wood grain samples, made in code with the engine's
## FastNoiseLite (a few milliseconds). Only its instance id is kept here, so the texture lives
## while some plank or material uses it and nothing static holds it when the game quits.

const SIZE := 256

## The instance id of the shared object, so nothing static holds it (not even a WeakRef).
static var _id := 0


static func texture() -> ImageTexture:
	if _id != 0 and is_instance_id_valid(_id):
		var held: Object = instance_from_id(_id)
		if held is ImageTexture:
			return held
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = 7
	noise.frequency = 0.03
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	var image := noise.get_seamless_image(SIZE, SIZE, false, false, 0.1, true)
	image.convert(Image.FORMAT_L8)
	image.generate_mipmaps()
	var tex := ImageTexture.create_from_image(image)
	_id = tex.get_instance_id()
	return tex
