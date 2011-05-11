function render(data,canvas) {

	var classes = pv.nodes(data);

	var format = pv.Format.number();

	var vis = new pv.Panel()
//	.width(document.body.clientWidth)
//	.height(document.body.clientHeight)
//	.event("mousedown", pv.Behavior.pan())
	.event("mousewheel", pv.Behavior.zoom())
	.canvas(canvas);

 // document.location.href=

	var pack = vis.add(pv.Layout.Pack)
	.top(-50)
	.bottom(-50)
	.nodes(classes)
	.size(function(d) (d.nodeValue.value+1)*1000)
	.spacing(0)
	.order(null)
	.node.add(pv.Dot)
	.event("click", function(d) self.location.href=d.nodeValue.link)
//	.event("mouseover", function() this.fillStyle("orange"))
//	.event("mouseout", function() this.fillStyle(undefined))
	.fillStyle(pv.Colors.category19().by(function(d) d.nodeValue.name))
	.strokeStyle(function() this.fillStyle().darker())
	.visible(function(d) d.parentNode)
	.title(function(d) d.nodeValue.name + ": " + format(d.nodeValue.value))
	.anchor("center").add(pv.Label)
	.text(function(d) d.nodeValue.name.substring(0, d.nodeValue.value*4))
	;

	vis.render();
}

function graph(data,canvas) {

	var classes = pv.nodes(data);

	var format = pv.Format.number();

	var vis = new pv.Panel()
//	.width(document.body.clientWidth)
//	.height(document.body.clientHeight)
//	.event("mousedown", pv.Behavior.pan())
	.event("mousewheel", pv.Behavior.zoom())
	.canvas(canvas);

 // document.location.href=

	var force = vis.add(pv.Layout.Force)
	      .nodes(followers.nodes)
	      .links(followers.links)
	      .springConstant(0.05)
	      .chargeConstant(-80)
	      .springLength(200);
	
	force.link.add(pv.Line);
    force.node.add(pv.Dot)
      .size(function(d){ return (d.linkDegree + 4) * Math.pow(this.scale, -1.5);})
//      .fillStyle(function(d){ return d.fix ? "brown" : colors(d.group);})
      .strokeStyle(function(){ return this.fillStyle().darker();})
      .lineWidth(1)
      .title(function(d){return d.nodeName;})
      .add(pv.Label).textAlign("center").text(function(n) {return n.nodeName})
      .event("mousedown", pv.Behavior.drag())
      .event("drag", force);	

	vis.render();
}
