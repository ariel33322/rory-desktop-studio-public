.pragma library
function defaults(){return {baseVisible:true,intervals:[]}}
function wrap(t){return ((t%1)+1)%1}
function validate(value){
 if(value===undefined)return defaults()
 if(!value || typeof value.baseVisible!=="boolean" || !Array.isArray(value.intervals) || value.intervals.length>1024)throw new Error("Recortes inválidos o más de 1024 intervalos")
 for(const span of value.intervals)if(!span || !Number.isFinite(span.start) || span.start<0 || span.start>=1 || !Number.isFinite(span.length) || span.length<0 || span.length>1 || typeof span.visible!=="boolean")throw new Error("Intervalo de recorte inválido")
 return value
}
function contains(span,t){return span.length===1 || span.length>0 && wrap(t-span.start)<span.length-1e-10}
function visibleAt(cuts,t){let shown=cuts.baseVisible;for(const span of cuts.intervals)if(contains(span,t))shown=span.visible;return shown}
// Compile only on document/geometry changes; rendering uses cached masks and runs.
function heapPush(heap,value){let i=heap.length;heap.push(value);while(i>0){const parent=(i-1)>>1;if(heap[parent]>=value)break;heap[i]=heap[parent];i=parent}heap[i]=value}
function heapPop(heap){const last=heap.pop();if(!heap.length)return;let i=0;while(i*2+1<heap.length){let child=i*2+1;if(child+1<heap.length && heap[child+1]>heap[child])child++;if(heap[child]<=last)break;heap[i]=heap[child];i=child}heap[i]=last}
function runs(cuts){
 const events=[],active=[],heap=[],result=[]
 function segment(a,b,index){if(b-a>1e-10){events.push({t:a,index:index,on:true},{t:b,index:index,on:false})}}
 for(let i=0;i<cuts.intervals.length;i++){
  const span=cuts.intervals[i];active.push(false)
  if(span.length===1)segment(0,1,i)
  else{const end=span.start+span.length;segment(span.start,Math.min(1,end),i);if(end>1)segment(0,end-1,i)}
 }
 events.push({t:0,index:-1,on:false},{t:1,index:-1,on:false});events.sort((a,b)=>a.t-b.t)
 let cursor=0
 while(cursor<events.length){
  const start=events[cursor].t
  while(cursor<events.length && events[cursor].t===start){const event=events[cursor++];if(event.index>=0){active[event.index]=event.on;if(event.on)heapPush(heap,event.index)}}
  while(heap.length && !active[heap[0]])heapPop(heap)
  const end=cursor<events.length ? events[cursor].t : 1,shown=heap.length ? cuts.intervals[heap[0]].visible : cuts.baseVisible
  if(shown && end-start>1e-10){if(result.length && Math.abs(result[result.length-1].end-start)<1e-9)result[result.length-1].end=end;else result.push({start:start,end:end})}
 }
 return result
}
function mask(cuts,count){const intervals=runs(cuts);return Array.from({length:count},(_,i)=>intervals.some(span=>i/count>=span.start-1e-10 && i/count<span.end-1e-10))}
function interpolate(a,b,t){const w=(t-a.t)/Math.max(1e-10,b.t-a.t);return {x:a.x+(b.x-a.x)*w,y:a.y+(b.y-a.y)*w,nx:a.nx+(b.nx-a.nx)*w,ny:a.ny+(b.ny-a.ny)*w,t:t}}
function pointAt(points,t){
 if(!points.length)return {x:0,y:0,nx:0,ny:-1,t:t}
 const first=Object.assign({},points[0],{t:points[0].t===undefined ? 0 : points[0].t})
 if(t<=first.t)return first
 for(let i=1;i<=points.length;i++){
  const a=points[i-1],b=i<points.length ? points[i] : Object.assign({},first,{t:1})
  if(t<=b.t+1e-10)return interpolate(a,b,t)
 }
 return first
}
function splitPath(points,intervals){
 return intervals.map(span=>[pointAt(points,span.start)].concat(points.filter(point=>point.t>span.start && point.t<span.end),[pointAt(points,span.end)]))
}
function append(cuts,start,length,visible){const value=JSON.parse(JSON.stringify(cuts));value.intervals.push({start:wrap(start),length:Math.max(0,Math.min(1,length)),visible:visible});return validate(value)}

function visibleSpans(cuts){
 const spans=runs(cuts).map(run=>({start:run.start,length:run.end-run.start,visible:true}))
 if(spans.length>1 && spans[0].start===0 && Math.abs(spans[spans.length-1].start+spans[spans.length-1].length-1)<1e-9){
  const first=spans.shift();spans[spans.length-1].length+=first.length
 }
 return {baseVisible:false,intervals:spans}
}
