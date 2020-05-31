# Python 破解BiliBili滑块验证码
>| 完美是不可能的，加个**震惊！Python破解BiliBili滑块验证码，完美避开人机识别**，可以有

**准备工作**
- B站登录页 https://passport.bilibili.com/login
- python3
- pip install selenium （webdriver框架）
- pip install PIL （图片处理）
- chrome driver：http://chromedriver.storage.googleapis.com/index.html
- firefox driver：https://github.com/mozilla/geckodriver/releases

![B站滑块验证码](https://img-blog.csdnimg.cn/20200216174309510.gif)

B站的滑块验证码如上。
这类验证码可以使用 selenium 操作浏览器拖拽滑块来进行破解，难点两个，一个如何确定拖拽到的位置，另一个是避开人机识别（反爬虫）。


## 确定滑块验证码需要拖拽的位移距离
有三种方式
- 人工智能机器学习，确定滑块位置
- 通过完整图片与缺失滑块的图片进行像素对比，确定滑块位置
- 边缘检测算法，确定位置

各有优缺点。人工智能机器学习，确定滑块位置，需要进行训练，比较麻烦，也可以看是否存在在线api可以调用。以下介绍其他两种方式。

### 对比完整图片与缺失滑块的图片
>| 仅介绍，本文不进行实现。对于B站来说，是准确率最高的方式（100%），但不能保证未来B站的滑块验证升级，导致不可用。

B站的滑块验证模块，一共有三张图片：完整图、缺失滑块图、滑块图，都是由画布绘制出的。类似于：

完整图：
![完整图](https://img-blog.csdnimg.cn/20200216175432603.png)
缺失滑块图：
![缺失滑块图](https://img-blog.csdnimg.cn/20200216175943681.png)
滑块图：
![滑块图](https://img-blog.csdnimg.cn/20200216180005919.png)

HTML代码类似于：
```html
<div class="geetest_canvas_img geetest_absolute" style="display: block;">
<div class="geetest_slicebg geetest_absolute">
	<canvas class="geetest_canvas_bg geetest_absolute" height="160" width="260"></canvas>
	<canvas class="geetest_canvas_slice geetest_absolute" width="260" height="160"></canvas>
</div>
<canvas class="geetest_canvas_fullbg geetest_fade geetest_absolute" height="160" width="260" style="display: none;"></canvas>
</div>

```

只需要通过selenium获取画布元素，执行js拿到画布像素，遍历完整图和缺失滑块图的像素，一旦获取到差异（需要允许少许像素误差），像素矩阵x轴方向即是滑块位置。
另外由于滑块图距离画布坐标原点有距离，还需要减去这部分距离。
最后使用 selenium 拖拽即可。

### 边缘检测算法，确定位置
>| 滑块基本上是个方形，通过算法确定方形起始位置即可。

![计算位置](https://img-blog.csdnimg.cn/20200216182718364.png)
介绍两种方式

- 滑块是方形的，存在垂直与水平的边，该边在缺失滑块图中基本都是灰黑的。遍历像素找到基本都是灰黑的边即可。
- 缺失滑块图中滑块位置是灰黑封闭的。通过算法可以找到封闭区域，大小与滑块相近，即是滑块需要拖拽到的位置。

第二种实现起来有些复杂，不进行实现了。
下面是第一种实现方式（`只实现了垂直边的检测，水平边检测原理一致`），会存在检测不出或错误的情况，使用时需要换一张验证码。也可能存在检测出的边是另一条（因为B站的滑块不是长方形，存在弧形边），那么需要减去滑块宽度

```python

class VeriImageUtil():

    def __init__(self):
        self.defaultConfig = {
            "grayOffset": 20,
            "opaque": 1,
            "minVerticalLineCount": 30
        }
        self.config = copy.deepcopy(self.defaultConfig)

    def updateConfig(self, config):
        # temp = copy.deepcopy(config)
        for k in self.config:
            if k in config.keys():
                self.config[k] = config[k]

    def getMaxOffset(self, *args):
        # 计算偏移平均值最大的数
        av = sum(args) / len(args)

        maxOffset = 0
        for a in args:
            offset = abs(av - a)
            if offset > maxOffset:
                maxOffset = offset
        return maxOffset

    def isGrayPx(self, r, g, b):
        # 是否是灰度像素点，允许波动offset
        return self.getMaxOffset(r, g, b) < self.config["grayOffset"]

    def isDarkStyle(self, r, g, b):
        # 灰暗风格
        return r < 128 and g < 128 and b < 128

    def isOpaque(self, px):
        # 不透明
        return px[3] >= 255 * self.config["opaque"]

    def getVerticalLineOffsetX(self, bgImage):
        # bgImage = Image.open("./image/bg.png")
        # bgImage.im.mode = 'RGBA'
        bgBytes = bgImage.load()

        x = 0
        while x < bgImage.size[0]:
            y = 0
            # 点》》线，灰度线条数量
            verticalLineCount = 0

            while y < bgImage.size[1]:
                px = bgBytes[x, y]
                r = px[0]
                g = px[1]
                b = px[2]
                # alph = px[3]
                # print(px)
                if self.isDarkStyle(r, g, b) and self.isGrayPx(r, g, b) and self.isOpaque(px):
                    verticalLineCount += 1
                else:
                    verticalLineCount = 0
                    y += 1
                    continue

                if verticalLineCount >= self.config["minVerticalLineCount"]:
                    # 连续多个像素都是灰度像素，直线
                    # print(x, y)
                    return x

                y += 1

            x += 1
        pass


if __name__ == '__main__':
    bgImage = Image.open("./image/bg.png")
    veriImageUtil = VeriImageUtil()

    # veriImageUtil.updateConfig({
    #     "grayOffset": 20,
    #     "opaque": 0.6,
    #     "minVerticalLineCount": 10
    # })
        bgOffsetX = veriImageUtil.getVerticalLineOffsetX(bgImage)
    print("bgOffsetX:{} ".format(bgOffsetX))

```
## 使用selenium进行滑动验证（会失败）

首先，我们需要从html中获取滑块验证的图片，通过执行js，将画布像素转为base64，然后python即可获取，进行拖拽处理：

```python

from selenium import webdriver
import time
import base64
from PIL import Image
from io import BytesIO
from selenium.webdriver.support.ui import WebDriverWait

def checkVeriImage(driver):    
    WebDriverWait(driver, 5).until(
        lambda driver: driver.find_element_by_css_selector('.geetest_canvas_bg.geetest_absolute'))
    time.sleep(1)
    im_info = driver.execute_script(
        'return document.getElementsByClassName("geetest_canvas_bg geetest_absolute")[0].toDataURL("image/png");')
    # 拿到base64编码的图片信息
    im_base64 = im_info.split(',')[1]
    # 转为bytes类型
    im_bytes = base64.b64decode(im_base64)
    with open('./temp_bg.png', 'wb') as f:
        # 保存图片到本地，方便查看预览
        f.write(im_bytes)
        
    image_data = BytesIO(im_bytes)
    bgImage = Image.open(image_data)
    # 滑块距离左边有 5~10 像素左右误差
    offsetX = VeriImageUtil().getVerticalLineOffsetX(bgImage)
    eleDrag = driver.find_element_by_css_selector(".geetest_slider_button")
    action_chains = webdriver.ActionChains(driver)
    action_chains.drag_and_drop_by_offset(eleDrag,offsetX-10,0).perform()
```

貌似可以了，但实际上，验证时会遇到“拼图被怪物吃掉了，请重试”，导致失败。这是因为被检测到机器人（爬虫）操作了。

## 避开人机识别
>| B站滑块验证码的人机识别，其实不咋滴，主要靠是否存在停留间隔来判断。一开始被网上文章误导，弄了什么距离=初速度乘以时间t + 1/2加速度乘以(时间平方)模拟拖拽，实际上是完全不对路的。

![人机识别-怪物吃了拼图](https://img-blog.csdnimg.cn/20200216200339129.gif)

`webdriver.ActionChains(driver).drag_and_drop_by_offset(eleDrag,offsetX-10,0).perform()` 拖动滑块会导致验证失败。在B站中，这是因为这个动作太快了的缘故。
有的同学就打算直接加 `time.sleep(1)` 了，这么做是不会成功的，会提示`拼图被怪物吃掉了，请重试`

实际上人做滑块验证的过程可以归为：手指快速拖拽验证码到指定位置，修正误差，停留一会儿，释放滑块。

### 简单实现
代码可以简单实现，都不需要模拟人修正拖拽误差的过程，普通网站不会去统计这个，至少B站不会。

```python
    def simpleSimulateDragX(self, source, targetOffsetX):
        """
        简单拖拽模仿人的拖拽：快速沿着X轴拖动，直接一步到达正确位置，再暂停一会儿，然后释放拖拽动作
        B站是依据是否有暂停时间来分辨人机的，这个方法适用。
        :param source: 
        :param targetOffsetX: 
        :return: None
        """
		#参考`drag_and_drop_by_offset(eleDrag,offsetX-10,0)`的实现，使用move方法
        action_chains = webdriver.ActionChains(self.driver)
        # 点击，准备拖拽
        action_chains.click_and_hold(source)
        action_chains.pause(0.2)
        action_chains.move_by_offset(targetOffsetX,0)
        action_chains.pause(0.6)
        action_chains.release()
        action_chains.perform()


```

### 添加修正过程的实现
其实也就最后一段多出了fix的过程， ` action_chains.move_by_offset(10,0)` 

```python
    def fixedSimulateDragX(self, source, targetOffsetX):
		#参考`drag_and_drop_by_offset(eleDrag,offsetX-10,0)`的实现，使用move方法
        action_chains = webdriver.ActionChains(self.driver)
        # 点击，准备拖拽
        action_chains.click_and_hold(source)
        action_chains.pause(0.2)
        action_chains.move_by_offset(targetOffsetX-10,0)
        action_chains.pause(0.6)
        action_chains.move_by_offset(10,0)
        action_chains.pause(0.6)
        action_chains.release()
        action_chains.perform()

```
### 终极版实现
>| 为了更像人类操作，可以进行拖拽间隔时间和拖拽次数、距离的随机化。虽然这对B站没什么用，还可能会导致验证时间变久一些。

拖拽多次，可以使用循环遍历，不过代码可能不好理解，直接判断就行，最多也就两到3次就完成修正误差的过程。

```python

    def __getRadomPauseScondes(self):
        """
        :return:随机的拖动暂停时间
        """
        return random.uniform(0.6, 0.9)

    def simulateDragX(self, source, targetOffsetX):
        """
        模仿人的拖拽动作：快速沿着X轴拖动（存在误差），再暂停，然后修正误差
        防止被检测为机器人，出现“图片被怪物吃掉了”等验证失败的情况
        :param source:要拖拽的html元素
        :param targetOffsetX: 拖拽目标x轴距离
        :return: None
        """
        action_chains = webdriver.ActionChains(self.driver)
        # 点击，准备拖拽
        action_chains.click_and_hold(source)
        # 拖动次数，二到三次
        dragCount = random.randint(2, 3)
        if dragCount == 2:
            # 总误差值
            sumOffsetx = random.randint(-15, 15)
            action_chains.move_by_offset(targetOffsetX + sumOffsetx, 0)
            # 暂停一会
            action_chains.pause(self.__getRadomPauseScondes())
            # 修正误差，防止被检测为机器人，出现图片被怪物吃掉了等验证失败的情况
            action_chains.move_by_offset(-sumOffsetx, 0)
        elif dragCount == 3:
            # 总误差值
            sumOffsetx = random.randint(-15, 15)
            action_chains.move_by_offset(targetOffsetX + sumOffsetx, 0)
            # 暂停一会
            action_chains.pause(self.__getRadomPauseScondes())

            # 已修正误差的和
            fixedOffsetX = 0
            # 第一次修正误差
            if sumOffsetx < 0:
                offsetx = random.randint(sumOffsetx, 0)
            else:
                offsetx = random.randint(0, sumOffsetx)

            fixedOffsetX = fixedOffsetX + offsetx
            action_chains.move_by_offset(-offsetx, 0)
            action_chains.pause(self.__getRadomPauseScondes())

            # 最后一次修正误差
            action_chains.move_by_offset(-sumOffsetx + fixedOffsetX, 0)
            action_chains.pause(self.__getRadomPauseScondes())

        else:
            raise Exception("莫不是系统出现了问题？!")

        # 参考action_chains.drag_and_drop_by_offset()
        action_chains.release()
        action_chains.perform()

```

## 终章（完整代码）
>| 示例代码和效果图。完整示例代码本身只是示例，方便测试用的，不进行成功验证等处理，验证成功后python会直接异常退出。


![效果图](https://img-blog.csdnimg.cn/20200216195136458.gif)

本文完整示例代码如下

```python
# -*- coding: utf-8 -*-
# @Date:2020/2/15 2:09
# @Author: Lu
# @Description bilibili滑块验证码识别。B站有反爬限制，过快地拖拽会提示“怪物吃了拼图，请重试”。
# 目前B站有三张图片，只要对比完整图和缺失滑块背景图的像素，就可以得到偏移图片y轴距离，减去滑块空白距离=需要滑动的像素距离
# 这里采用边缘检测，检测缺失滑块的底图是否存在一条灰色竖线，即认为是滑块目标位置，存在失败的概率，适用范围应该更大些。


from selenium import webdriver
import time
import base64
from PIL import Image
from io import BytesIO
from selenium.webdriver.support.ui import WebDriverWait
import random
import copy


class VeriImageUtil():

    def __init__(self):
        self.defaultConfig = {
            "grayOffset": 20,
            "opaque": 1,
            "minVerticalLineCount": 30
        }
        self.config = copy.deepcopy(self.defaultConfig)

    def updateConfig(self, config):
        # temp = copy.deepcopy(config)
        for k in self.config:
            if k in config.keys():
                self.config[k] = config[k]

    def getMaxOffset(self, *args):
        # 计算偏移平均值最大的数
        av = sum(args) / len(args)

        maxOffset = 0
        for a in args:
            offset = abs(av - a)
            if offset > maxOffset:
                maxOffset = offset
        return maxOffset

    def isGrayPx(self, r, g, b):
        # 是否是灰度像素点，允许波动offset
        return self.getMaxOffset(r, g, b) < self.config["grayOffset"]

    def isDarkStyle(self, r, g, b):
        # 灰暗风格
        return r < 128 and g < 128 and b < 128

    def isOpaque(self, px):
        # 不透明
        return px[3] >= 255 * self.config["opaque"]

    def getVerticalLineOffsetX(self, bgImage):
        # bgImage = Image.open("./image/bg.png")
        # bgImage.im.mode = 'RGBA'
        bgBytes = bgImage.load()

        x = 0
        while x < bgImage.size[0]:
            y = 0
            # 点》》线，灰度线条数量
            verticalLineCount = 0

            while y < bgImage.size[1]:
                px = bgBytes[x, y]
                r = px[0]
                g = px[1]
                b = px[2]
                # alph = px[3]
                # print(px)
                if self.isDarkStyle(r, g, b) and self.isGrayPx(r, g, b) and self.isOpaque(px):
                    verticalLineCount += 1
                else:
                    verticalLineCount = 0
                    y += 1
                    continue

                if verticalLineCount >= self.config["minVerticalLineCount"]:
                    # 连续多个像素都是灰度像素，直线，认为需要滑动这么多
                    # print(x, y)
                    return x

                y += 1

            x += 1
        pass


class DragUtil():
    def __init__(self, driver):
        self.driver = driver

    def __getRadomPauseScondes(self):
        """
        :return:随机的拖动暂停时间
        """
        return random.uniform(0.6, 0.9)

    def simulateDragX(self, source, targetOffsetX):
        """
        模仿人的拖拽动作：快速沿着X轴拖动（存在误差），再暂停，然后修正误差
        防止被检测为机器人，出现“图片被怪物吃掉了”等验证失败的情况
        :param source:要拖拽的html元素
        :param targetOffsetX: 拖拽目标x轴距离
        :return: None
        """
        action_chains = webdriver.ActionChains(self.driver)
        # 点击，准备拖拽
        action_chains.click_and_hold(source)
        # 拖动次数，二到三次
        dragCount = random.randint(2, 3)
        if dragCount == 2:
            # 总误差值
            sumOffsetx = random.randint(-15, 15)
            action_chains.move_by_offset(targetOffsetX + sumOffsetx, 0)
            # 暂停一会
            action_chains.pause(self.__getRadomPauseScondes())
            # 修正误差，防止被检测为机器人，出现图片被怪物吃掉了等验证失败的情况
            action_chains.move_by_offset(-sumOffsetx, 0)
        elif dragCount == 3:
            # 总误差值
            sumOffsetx = random.randint(-15, 15)
            action_chains.move_by_offset(targetOffsetX + sumOffsetx, 0)
            # 暂停一会
            action_chains.pause(self.__getRadomPauseScondes())

            # 已修正误差的和
            fixedOffsetX = 0
            # 第一次修正误差
            if sumOffsetx < 0:
                offsetx = random.randint(sumOffsetx, 0)
            else:
                offsetx = random.randint(0, sumOffsetx)

            fixedOffsetX = fixedOffsetX + offsetx
            action_chains.move_by_offset(-offsetx, 0)
            action_chains.pause(self.__getRadomPauseScondes())

            # 最后一次修正误差
            action_chains.move_by_offset(-sumOffsetx + fixedOffsetX, 0)
            action_chains.pause(self.__getRadomPauseScondes())

        else:
            raise Exception("莫不是系统出现了问题？!")

        # 参考action_chains.drag_and_drop_by_offset()
        action_chains.release()
        action_chains.perform()

    def simpleSimulateDragX(self, source, targetOffsetX):
        """
        简单拖拽模仿人的拖拽：快速沿着X轴拖动，直接一步到达正确位置，再暂停一会儿，然后释放拖拽动作
        B站是依据是否有暂停时间来分辨人机的，这个方法适用。
        :param source: 
        :param targetOffsetX: 
        :return: None
        """

        action_chains = webdriver.ActionChains(self.driver)
        # 点击，准备拖拽
        action_chains.click_and_hold(source)
        action_chains.pause(0.2)
        action_chains.move_by_offset(targetOffsetX, 0)
        action_chains.pause(0.6)
        action_chains.release()
        action_chains.perform()

def checkVeriImage(driver):
    WebDriverWait(driver, 5).until(
        lambda driver: driver.find_element_by_css_selector('.geetest_canvas_bg.geetest_absolute'))
    time.sleep(1)
    im_info = driver.execute_script(
        'return document.getElementsByClassName("geetest_canvas_bg geetest_absolute")[0].toDataURL("image/png");')
    # 拿到base64编码的图片信息
    im_base64 = im_info.split(',')[1]
    # 转为bytes类型
    im_bytes = base64.b64decode(im_base64)
    with open('./temp_bg.png', 'wb') as f:
        # 保存图片到本地
        f.write(im_bytes)

    image_data = BytesIO(im_bytes)
    bgImage = Image.open(image_data)
    # 滑块距离左边有 5 像素左右误差
    offsetX = VeriImageUtil().getVerticalLineOffsetX(bgImage)
    print("offsetX: {}".format(offsetX))
    if not type(offsetX) == int:
        # 计算不出，重新加载
        driver.find_element_by_css_selector(".geetest_refresh_1").click()
        checkVeriImage(driver)
        return
    elif offsetX == 0:
        # 计算不出，重新加载
        driver.find_element_by_css_selector(".geetest_refresh_1").click()
        checkVeriImage(driver)
        return
    else:
        dragVeriImage(driver, offsetX)


def dragVeriImage(driver, offsetX):
    # 可能产生检测到右边缘的情况
    # 拖拽
    eleDrag = driver.find_element_by_css_selector(".geetest_slider_button")
    dragUtil = DragUtil(driver)
    dragUtil.simulateDragX(eleDrag, offsetX - 10)
    time.sleep(2.5)

    if isNeedCheckVeriImage(driver):
        checkVeriImage(driver)
        return
    dragUtil.simulateDragX(eleDrag, offsetX - 6)

    time.sleep(2.5)
    if isNeedCheckVeriImage(driver):
        checkVeriImage(driver)
        return
    # 滑块宽度40左右
    dragUtil.simulateDragX(eleDrag, offsetX - 56)

    time.sleep(2.5)
    if isNeedCheckVeriImage(driver):
        checkVeriImage(driver)
        return
    dragUtil.simulateDragX(eleDrag, offsetX - 52)

    if isNeedCheckVeriImage(driver):
        checkVeriImage(driver)
        return


def isNeedCheckVeriImage(driver):
    if driver.find_element_by_css_selector(".geetest_panel_error").is_displayed():
        driver.find_element_by_css_selector(".geetest_panel_error_content").click();
        return True
    return False


def task():
    # 此步骤很重要，设置chrome为开发者模式，防止被各大网站识别出来使用了Selenium
    # options = webdriver.ChromeOptions()
    # options.add_experimental_option('excludeSwitches', ['enable-automation'])

    options = webdriver.FirefoxOptions()

    # driver = webdriver.Firefox(executable_path=r"../../../res/webdriver/geckodriver_x64_0.26.0.exe",options=options)
    driver = webdriver.Firefox(executable_path=r"../../../res/webdriver/geckodriver_x64_0.26.0.exe",options=options)

    driver.get('https://passport.bilibili.com/login')
    time.sleep(3)

    driver.find_element_by_css_selector("#login-username").send_keys("1234567")
    driver.find_element_by_css_selector("#login-passwd").send_keys("abcdefg")
    driver.find_element_by_css_selector(".btn.btn-login").click()
    time.sleep(2)
    checkVeriImage(driver)

    pass


#   该方法用来确认元素是否存在，如果存在返回flag=true，否则返回false
def isElementExist(driver, css):
    try:
        driver.find_element_by_css_selector(css)
        return True
    except:
        return False


if __name__ == '__main__':
    task()

```


