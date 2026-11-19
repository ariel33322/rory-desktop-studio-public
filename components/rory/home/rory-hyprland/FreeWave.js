.pragma library
// Handles are offsets from anchors; moving an anchor preserves its curvature.
function copy(value){return JSON.parse(JSON.stringify(value))}
function valid(value){
 if(!value || value.version!==1 || !Array.isArray(value.points) || value.points.length<6 || value.points.length>128 || value.points.length%2 || !value.points.every(v=>typeof v==='number' && Number.isFinite(v) && Math.abs(v)<=3))return false
 const n=value.points.length/2
 return ['straight','smooth','bezier'].indexOf(value.mode)>=0 && Number.isFinite(value.rounding) && value.rounding>=0 && value.rounding<=1 && Array.isArray(value.kinds) && value.kinds.length===n && value.kinds.every(v=>v==='corner' || v==='smooth') && Array.isArray(value.handles) && value.handles.length===n*4 && value.handles.every(v=>typeof v==='number' && Number.isFinite(v) && Math.abs(v)<=6)
}
function create(points){const n=points.length/2,p={version:1,points:points.slice(),mode:'smooth',rounding:1,kinds:Array(n).fill('smooth'),handles:Array(n*4).fill(0)};for(let i=0;i<n;i++)resetHandles(p,i);return p}
function tangent(p,i){const n=p.points.length/2,a=(i+n-1)%n,b=(i+1)%n;return [(p.points[b*2]-p.points[a*2])/6,(p.points[b*2+1]-p.points[a*2+1])/6]}
function resetHandles(p,i){const t=tangent(p,i);p.handles.splice(i*4,4,-t[0],-t[1],t[0],t[1])}
function controls(p,i){
 const n=p.points.length/2,j=(i+1)%n,a=[p.points[i*2],p.points[i*2+1]],b=[p.points[j*2],p.points[j*2+1]]
 if(p.mode==='straight' || p.kinds[i]==='corner')return [a,a,b,b]
 const ta=p.mode==='bezier' ? [p.handles[i*4+2],p.handles[i*4+3]] : tangent(p,i)
 const tb=p.mode==='bezier' ? [p.handles[j*4],p.handles[j*4+1]] : tangent(p,j).map(v=>-v)
 return [a,[a[0]+ta[0]*p.rounding,a[1]+ta[1]*p.rounding],[b[0]+tb[0]*p.rounding,b[1]+tb[1]*p.rounding],b]
}
function sample(p,i,t){
 const c=controls(p,i),u=1-t
 if(p.mode==='straight' || p.kinds[i]==='corner')return {x:c[0][0]*u+c[3][0]*t,y:c[0][1]*u+c[3][1]*t,dx:c[3][0]-c[0][0],dy:c[3][1]-c[0][1]}
 const v={};for(let k=0;k<2;k++){v[k===0?'x':'y']=u*u*u*c[0][k]+3*u*u*t*c[1][k]+3*u*t*t*c[2][k]+t*t*t*c[3][k];v[k===0?'dx':'dy']=3*u*u*(c[1][k]-c[0][k])+6*u*t*(c[2][k]-c[1][k])+3*t*t*(c[3][k]-c[2][k])}if(Math.hypot(v.dx,v.dy)<1e-9){v.dx=c[3][0]-c[0][0];v.dy=c[3][1]-c[0][1]}return v
}
function insert(p,edge,t){
 if(p.points.length>=128)return -1
 const n=p.points.length/2,i=((edge%n)+n)%n,j=(i+1)%n;t=Math.max(.001,Math.min(.999,t));const c=controls(p,i),at=sample(p,i,t),idx=i+1
 function mix(a,b){return [a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t]}
 const a=mix(c[0],c[1]),b=mix(c[1],c[2]),d=mix(c[2],c[3]),e=mix(a,b),f=mix(b,d)
 // Exact subdivision for manual Bézier segments, including the closing segment.
 if(p.mode==='bezier' && p.kinds[i]!=='corner' && p.rounding>0){const r=p.rounding;p.handles[i*4+2]=(a[0]-c[0][0])/r;p.handles[i*4+3]=(a[1]-c[0][1])/r;p.handles[j*4]=(d[0]-c[3][0])/r;p.handles[j*4+1]=(d[1]-c[3][1])/r}
 p.points.splice(idx*2,0,at.x,at.y);p.kinds.splice(idx,0,p.kinds[i]);p.handles.splice(idx*4,0,0,0,0,0)
 if(p.mode==='bezier' && p.kinds[i]!=='corner' && p.rounding>0)p.handles.splice(idx*4,4,(e[0]-at.x)/p.rounding,(e[1]-at.y)/p.rounding,(f[0]-at.x)/p.rounding,(f[1]-at.y)/p.rounding)
 else resetHandles(p,idx)
 return idx
}
function remove(p,i){if(p.points.length<=6 || i<0 || i>=p.points.length/2)return false;p.points.splice(i*2,2);p.kinds.splice(i,1);p.handles.splice(i*4,4);return true}
