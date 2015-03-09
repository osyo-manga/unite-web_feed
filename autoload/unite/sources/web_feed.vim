scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


let s:V = vital#of("unite_web_feed")
let s:XML = s:V.import("Web.XML")
let s:Reunions = s:V.import("Reunions")



function! s:attr(node, name)
  let n = a:node.childNode(a:name)
  if empty(n)
    return ""
  endif
  return n.value()
endfunction


function! s:parse_feed(dom)
  let dom = a:dom
  let items = []
  if dom.name == 'rss'
    let channel = dom.childNode('channel')
    for item in channel.childNodes('item')
      call add(items, {
      \  "title": s:attr(item, 'title'),
      \  "link": s:attr(item, 'link'),
      \  "content": s:attr(item, 'description'),
      \  "id": s:attr(item, 'guid'),
      \  "date": s:attr(item, 'pubDate'),
      \})
    endfor
  elseif dom.name == 'rdf:RDF'
    for item in dom.childNodes('item')
      call add(items, {
      \  "title": s:attr(item, 'title'),
      \  "link": s:attr(item, 'link'),
      \  "content": s:attr(item, 'description'),
      \  "id": s:attr(item, 'guid'),
      \  "date": s:attr(item, 'dc:date'),
      \})
    endfor
  elseif dom.name == 'feed'
    for item in dom.childNodes('entry')
      call add(items, {
      \  "title": s:attr(item, 'title'),
      \  "link": item.childNode('link').attr['href'],
      \  "content": s:attr(item, 'content'),
      \  "id": s:attr(item, 'id'),
      \  "date": s:attr(item, 'updated'),
      \})
    endfor
  endif
  return items
endfunction


function! s:parse(content)
	let result = s:parse_feed(s:XML.parse(a:content))
	for item in result
		let item.content = s:XML.parse("<content>" . item.content . "</content>").value()
	endfor
	return result
endfunction


function! s:feed_process(url)
	return s:Reunions.http_get(a:url)
endfunction


let s:source = {
\	"name" : "web/feed",
\	"description" : "output feed",
\	"hooks" : {},
\	"count" : 0,
\}
let s:source.hooks.parent = s:source


function! s:source.hooks.on_init(args, context)
	if !has_key(a:context, "custom_web_feed_url")
		return unite#print_source_message("Plase use -custom-web-feed-url option.\ne.g. :Unite web/feed -custom-web-feed-url=https://pipes.yahoo.com/pipes/pipe.run?_id=adbe4a686d78c7eefd1712aeea893e7d&_render=rss", "web/feed")
	endif
	let self.parent.source__response = s:feed_process(a:context.custom_web_feed_url)
	let self.parent.count = 0
endfunction


function! s:source.hooks.on_close(args, context)
	if has_key(self.parent, "source__response")
		call self.parent.source__response.kill(1)
	endif
endfunction


function! s:source.async_gather_candidates(args, context)
	if !has_key(self, "source__response")
		let a:context.is_async = 0
		return [
\			{ "word" : "Plase use -custom-web-feed-url option."},
\			{ "word" : "e.g. :Unite web/feed -custom-web-feed-url=https://pipes.yahoo.com/pipes/pipe.run?_id=adbe4a686d78c7eefd1712aeea893e7d&_render=rss" }
\		]
	endif

	let a:context.source.unite__cached_candidates = []
	call self.source__response.update()
	if !self.source__response.is_exit()
		let self.count += 1
		return [{ "word" : "[untie-web/feed] web/feed" . " download" . repeat(".", self.count % 5) }]
	endif

	let a:context.is_async = 0
	let content = s:parse(self.source__response.get().content)
	let is_view_content = get(a:context, "custom_web_feed_view_content", 0)
	return map(content, '{
\		"word" : v:val.title . (is_view_content ? " : " . v:val.content  : ""),
\		"kind" : "uri",
\		"default_action" : "start",
\		"action__content" : v:val,
\		"action__path" : v:val.link
\	}')
endfunction


function! unite#sources#web_feed#define(...)
	return s:source
endfunction

if expand("%:p") == expand("<sfile>:p")
	call unite#define_source(s:source)
endif


let &cpo = s:save_cpo
unlet s:save_cpo
