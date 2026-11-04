# Dashboard sprite atlas

Generated with the built-in imagegen tool. Original atlas: 1536 x 1024, six objects in a 3 x 2 grid. Cropped at runtime by `scripts/dashboard_art.gd`; labels, digits and needle rotations are live game UI.

## Generation prompt

Use case: stylized-concept. Production game sprite atlas for a 2D sci-fi taxi dashboard, straight-on orthographic front view, crisp detailed painted retro arcade sprites, dark navy leather, aged brass and amber instrument lighting. Transparent background. Canvas wide 1536x1024 arranged exact 3 columns by 2 rows of equally sized cells. Each cell isolated with transparent padding; no overlap. Top left: blank wide rectangular dashboard fascia panel, rounded upper corners, leather padded top lip, brushed metal lower edge, screws, no instruments or text, fills cell. Top middle: circular analog fuel gauge, brass bezel, dark face, fine cream ticks, empty red arc on lower left and full green arc on lower right, sweep 270 degrees from bottom-left clockwise through top to bottom-right, NO NEEDLE, NO LETTERS OR NUMBERS. Top right: circular analog damage gauge same dimensions brass bezel dark face fine ticks, green arc on bottom-left and red arc on bottom-right, NO NEEDLE NO TEXT. Bottom left: blank rectangular mechanical odometer housing, brass rim dark recessed black window, NO DIGITS NO TEXT, width twice height. Bottom middle: one long slim red-orange analog gauge needle pointing straight RIGHT with circular brass pivot cap at LEFT end, no gauge. Bottom right: dark ribbed dashboard trim rectangular panel leather with narrow brass borders, no text. No shadows outside sprites. No perspective. All six assets large clean game-ready.

## Follow-up edit

Remove the backdrop between and around the six isolated objects while preserving their existing positions, dimensions, materials and dark interiors. Keep the needle and pivot as one object; no added text or details.
