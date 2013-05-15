package flash.display;


import flash.Lib;


class GraphicsSolidFill extends IGraphicsData {
	
	
	public function new (color:Int = 0, alpha:Float = 1.0) {
		
		super (nme_graphics_solid_fill_create (color, alpha));
		
	}
	
	
	private static var nme_graphics_solid_fill_create = Lib.load ("nme", "nme_graphics_solid_fill_create", 2);
	
	
}