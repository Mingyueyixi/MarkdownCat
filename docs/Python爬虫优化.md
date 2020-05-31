# Python 爬虫优化——设置不自动读取响应正文，避免自动读取大文件

有的童鞋可能发现，自己的项目，自从按推荐，升级uillib库到urllib3之后，爬虫什么的，有时候会特别耗时，然而自己只不过是分析一下网页，不该如此。

`排查时我们往往发现，在某个链接卡住了。`

这要从 Python 的 `urllib3`说起，它的网络请求默认会自动读取响应体正文。这会导致什么问题？导致一旦加载链接，直接全部读取，而网络上常常包含有图片、视频、压缩文件、软件、APP等体积较大甚至突破天际的文件。于是……悲剧就诞生了。

即使我们根据链接名称，过滤掉这些软件，然而仍会存在漏网之鱼——某些网站搞出来的链接，不包含文件后缀，导致不知道是否要过滤掉。怎么办？

答案是`对http响应头进行分析，符合条件，再读取响应正文`，http响应头中包含的东西很多，例如
`content-type: image/png` 与 `content-length: 960`

依据这些条件，可以判断文件类型（MimeType），文件大小之后，再决定是否读取。

对于使用urlib来说，不必担心，而使用urllib3以及以urllib3为基础的库（例如request），可能都存在该问题，urllib3则设置`preload_content=False`, 分析请求头之后再决定是否读取内容即可

```python
res = urllib3.request(method="GET", url=url,preload_content=False)
if int(content_length) > 1024 * 1024:
    # > 1M
    return
if "image" in content_type:
    res.data
……
```

PS
对于request库而言，默认很可能也是直接读取的，对应的配置是
stream: (optional) if ``False``, the response content will be immediately downloaded.



