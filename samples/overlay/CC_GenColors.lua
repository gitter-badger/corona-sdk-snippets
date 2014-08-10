--- "Colors"-generating phase of the colored corners demo.

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Standard library imports --
local yield = coroutine.yield

-- Modules --
local bitmap = require("ui.Bitmap")
local button = require("ui.Button")
local layout = require("utils.Layout")

-- Corona globals --
local display = display
local easing = easing
local transition = transition

-- Corona modules --
local composer = require("composer")

--
local Scene = composer.newScene()

-- --
local MoveParams = {
	x = display.contentCenterX, transition = easing.inOutExpo,

	onComplete = function(object)
		object.m_done = true
	end
}

--
function Scene:show (event)
	if event.phase == "did" then
		local params = event.params

		--
		local funcs, move_bitmaps = params.funcs
		local cancel = button.Button(self.view, nil, params.ok_x, 0, 100, 40, function()
			for i = 1, #(move_bitmaps or "") do
				transition.cancel(move_bitmaps[i])
			end

			funcs.Cancel()
			composer.showOverlay("samples.overlay.CC_ChooseFile", { params = params })
		end, "Cancel")

		layout.PutBelowY(cancel, params.ok_y, 30)

		funcs.Action(function()
			funcs.SetStatus("Loading image")

			local image = params.load_image()
			local pixels, w = image:GetPixels(), image:GetDims()

			funcs.SetStatus("Generating exemplars")

			local exemplars, tile_dim, prev = {}, params.tile_dim

			for i = 1, params.num_colors do
				--
				local exemplar, move_bitmaps, index, ypos = {}, {}, 1, params.color_pos[i]
				local color_image = bitmap.Bitmap(self.view)

				color_image:Resize(tile_dim, tile_dim) -- Needs some care to not run up against screen?

				layout.PutAtBottomLeft(color_image, "1%", "-2%")

				for y = 0, tile_dim - 1 do
					local xpos = ypos

					for x = 0, tile_dim - 1 do
						local sum = pixels[xpos + 1] + pixels[xpos + 2] + pixels[xpos + 3]

						exemplar[index], xpos, index = sum, xpos + 4, index + 1

						color_image:SetPixel(x, y, sum / (3 * 255))

						funcs.TryToYield()
					end

					ypos = ypos + 4 * w
				end

				color_image:WaitForPendingSets()

				--
				local cury = color_image.y

				if prev then
					layout.PutBelow(color_image, prev, "2%")
				else
					layout.PutBelowY(color_image, 0, "2%")
				end

				MoveParams.y, color_image.y, exemplars[i], prev = color_image.y, cury, exemplar, color_image

				move_bitmaps[i] = transition.to(color_image, MoveParams)

				repeat
					yield()
				until color_image.m_done

				--
				local frame, stroke = display.newRect(self.view, color_image.x, color_image.y, color_image.width, color_image.height), params.colors[i]

				frame.strokeWidth = 2

				frame:setFillColor(0, 0)
				frame:setStrokeColor(stroke[1], stroke[2], stroke[3])
				frame:translate(.5 * color_image.width, .5 * color_image.height)
			end

			funcs.SetStatus("Press OK to synthesize")

			button.Button(self.view, nil, params.ok_x, params.ok_y, 100, 40, function()
--				params.bitmap, params.energy, params.gray = image, values, energy.ToGray
				params.exemplars = exemplars

				funcs.ShowOverlay("samples.overlay.CC_Synthesize", params)
			end, "OK")
		end)()
	end
end

Scene:addEventListener("show")

return Scene