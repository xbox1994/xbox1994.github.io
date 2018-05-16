---
layout: post
title: "React Native组件设计实践"
date: 2017-11-18 20:12:55 +0800
comments: true
categories: 前端
---

本文中所提到的**组件**的定义是基于React Native官方提供的某个/些组件进行包装/组合的用户某个特定App的自定义组件，可能与业务相关，也可能无关。

<!-- more -->


#为什么要写组件
想象一下，你的每一个页面中除了工具类的引用之外没有任何一个import，当你写了几个页面之后发现很舒服，当你写下一个页面的时候你突然发现你可能需要：

1. 复制 + 粘贴
2. 花很多时间弄清楚之前的页面中写的是什么东西
3. 粘贴代码块过来之后需要修改调用的接口，造成代码更加混乱
4. 粘贴代码块过来之后需要增加一个功能，造成代码更加混乱
5. 难以控制组件的生命周期

那么与之对应的，如果使用组件，则可以解决上面的问题，所以归纳来说，在代码方面组件化的好处是：

1. **可复用性**
2. **单一且清晰的职责**
3. **接口规范**
4. **相互组合**
5. **生命周期管理**

在系统构建与工程实践上来说，好处还有：

1. **降低系统的耦合度**。使用了接口统一，互相独立的组件之后，想替换掉原来的组件则是添加一个组件、修改一个引用的事情。
2. **降低学习成本、使用难度**。来了个新成员只需要学习组件的使用方法就可以构建出成熟稳定的页面。
3. **大大提高团队开发效率**。复用已有的东西是最快的实现方式。
4. **便于测试**。

#从头开始，如何设计？
好了，我们现在知道了组件化的好处并且了解了组件的一些设计的原则，那么如果要你写一个APP，那么我们应该如何一开始就使用组件化的思想来设计整个应用呢？

在实现业务流程前，需要对项目的原型UI进行分解和分类，在React Native项目中，把UI组件分为了四种类型：

* Shared Component: 基础组件，Button，Label之类的大部分其它组件都会用到的基础组件，都是我们自己包装、组合官方组件形成的。
* Feature Component: 业务组件，对应到某个业务流程的子组件，但其不对应路由, 他们通过各种组合形成了Scene组件。
* Scene: 与路由对应的代表整个页面的组件，主要功能就是将上面两种子组件组合在一起。
* Router: 借助`react-native-router-flux`组件将Scene注册到这个路由表中，在Scene中使用Actions.xxx就可跳转到某个Scene，其实Router不算UI组件。

{% img /images/blog/2017-11-18_1.png 'image' %}

Router:

```
<Scene
  key="login"
  component={LoginContainer}
  hideNavBar
/>
```

Scene:

```
import React from 'react';
import { StyleSheet } from 'react-native';
import { Actions, ActionConst } from 'react-native-router-flux';
import { connect } from 'react-redux';
import * as _ from 'lodash';

function LogoutButton(props) {
  const handleLogout = () => {
    unbindDevice()
      .then(() => { props.logout().catch(_.noop); })
      .catch(_.noop);
    Actions.login({ type: ActionConst.REPLACE });
  };
  return (
    <Touchable onPress={handleLogout}>
      <Image source={logoutIcon} />
    </Touchable>
  );
}

const mapDispatchToProps = {
  logout,
};

export default connect(null, mapDispatchToProps)(LogoutButton);

```

Component:

```
function Touchable(props) {
  const isNoopPressHandler = _.isNil(props.onPress) || props.onPress === _.noop;
  return (
    <TouchableOpacity
      activeOpacity={props.activeOpacity}
      style={props.style}
      onPress={
        isNoopPressHandler ? _.noop :
          _.throttle(props.onPress, props.debounceMillisecond, { leading: true, trailing: false })
      }
      disabled={isNoopPressHandler ? true : props.isDisabled}
      onLayout={props.onLayout}
    >
      {props.children}
    </TouchableOpacity>
  );
}
```

看起来很简单对吧？那么难题来了，对于具体实践来说，如何设计某个页面中具体的组件？比如如何设计某个页面的布局、布局中的按钮、某个列表中的输入框控件，才能在保持松耦合的基础上实现组件的复用？下面以设计一个列表页为例来进行讲解。
#组件设计案例

{% img /images/blog/2017-11-18_2.png 'image' %}

##组件分析
在这张设计图中，一眼看去有不少互相独立的元素，所以最开始我们来按图中标示序号从父组件->子组件的方式梳理一遍，1号父组件包含2号子组件，3号父组件包含4~8子号组件，具体组件分析如下：

1. Header: 非Popup页面都需要用到的组件，故抽取为组件。提供部分功能或者后退、主页等流程上的跳转操作。
2. IconText: 有复用场景，故抽取为组件。携带Image的Text组件，外面套上TouchableOpacity组件即可成为Button使用。
3. DataList: 整个App中其他使用场景，故抽取为组件。可以左右切换的数据列表组件。
4. OrderRow: 对于处理中的订单的业务场景中，DataList中每行数据都需要它进行展示，故抽取为组件。
5. InfoPanel: 有复用场景，故抽取为组件。
6. ProgressBar: 实现复杂，与业务无关，需要提供单一的职责，故抽取为组件。
7. InputWithDateTimePicker: 实现复杂，与业务无关，需要提供单一的职责，故抽取为组件。
8. StatusBar: 实现复杂，与业务无关，需要提供单一的职责，故抽取为组件。

将组件分析出来之后，其实我们现在可以开始写代码了，但是能再进一步思考一下就更好了，上面提到，组件根据是否业务相关分成基础组件与业务组件，我的建议是能将组件写成基础组件就写成基础组件，实在与业务关联度比较大而无法提取出来才写成业务组件，因为可以最大程度的提高可复用性、明确组件职责进而相互组合。

##组件实现
除了OrderRow之外，所有的组件需要实现成为可以通过props或者childNode的方式来使用，通过传入style控制样式的，通过props的例子如下：

```
function InfoPanel(props) {
  return (
    <View style={[styles.containerOfAll, props.style]}>
      <View style={styles.title}>
        <Text
          numberOfLines={1}
          style={[
            styles.titleText,
            props.isWarning && styles.warningTitleText,
            props.textStyle]}
        >{props.title}</Text>
.......................
  );
}

InfoPanel.propTypes = {
  style: PROP_TYPES.STYLE,
  textStyle: PROP_TYPES.STYLE,
  title: React.PropTypes.string,
  ...........
};
.....
export default InfoPanel;
```

通过childNode的例子如下：

```

function FormInputField(props) {
  return (
    <View style={style}>
      <View style={styles.titleContainer}>
        <Text style={[styles.attributeName, textStyle]}>
          {name}
        </Text>
        {isMandatory && renderAsterisk()}
      </View>
      {children}
      {
          !_.isEmpty(error)
          && <Text style={styles.errorText}>{error}</Text>
        }
    </View>
  );
}

...
children: React.PropTypes.node.isRequired,
...
```

这两种方式的区别是：

* 从使用方式来说：前者是可以直接拿来使用的完整的组件，后者是需要传入自定义组件来将它们组合起来使用的一个组件。
* 从耦合关系上来说：前者可以是基于某个组件上再次强化封装的一个组件（如基石组件是Picker，提供了基本的下拉菜单的功能，后而添加了DateTimePicker、AddressPicker这样精确化数据的Picker），后者则是为了与子组件解耦形成的非常灵活的组件（FormInputField里就给了一个框架，上面是name，下面你想传什么就传什么，就可以合并成具有某个特定框架而又灵活的组件了）。

那么除此之外，OrderRow是业务组件，因为每一行中的所有子组件的排列顺序、style是需要根据业务需求写死在OrderRow的代码中的，同时也是为了之后的需求变更提供可操作余地，单就这个业务组件没有什么别的想法了。但是一旦出现其他Row，比如ReservationRow之类的控件，当你实现了之后你会发现他们在样式、组件排列方式、数据加载逻辑上可能基本是一样的，那么此时就需要开始重构了。重构的方式是使用React的[高阶组件](https://reactjs.org/docs/higher-order-components.html)，文中介绍的非常清楚，本文没有必要复制一遍。

最后的调用就会非常简单，在HomeContainer中就会使用到DataList与OrderRow，而OrderRow中调用了InfoPanel...：

```
<Scene
  key="home"
  component={HomeContainer}
  renderBackButton={() => <HomeLeftTitle />}
  renderTitle={() => <Logo style={styles.generalTitle} />}
  renderRightButton={() => <HomeRightTitle />}
/>
```

#组件设计与组件使用者的关系
> 你一看见这个Button的组件名字就应该知道这个Button是干什么的

{% img /images/blog/2017-11-18_3.png 'image' %}

比如[Bootstrap Button](https://v4-alpha.getbootstrap.com/components/buttons/)的设计，按钮按**功能**被分成了7类，不同功能的Button对应一个名称与某个默认样式。虽然是将名字与按钮的功能绑定、耦合在一起，但是这是一种必要的耦合，否则无法根据你想要的功能索引到具体的Button。

现在，如果我想添加一种按钮，功能就是确认与取消，但是现在Primary和Secondary提供的默认样式不能满足我。实现有两种方式：

1. 添加两种新的类型叫做BlackPrimary和BlackSecondary。
2. 在Primary与Secondary的类别下提供一个可修改style的接口。

那么第一种就是将视觉和功能耦合在一起，也就是说每次我想添加一个不同颜色的按钮就需要创建一个新的类型，那么什么RedPrimary/BluePrimary都会出来了，这样就违反了原来按功能分类的初衷。那么你一定会想问，为什么不能按颜色来分类呢？因为对于颜色附着于Button这样的组件上的时候就会显得难以根据颜色来索引到某个功能，比如蓝色到底是确认键呢还是取消键呢？并且更重要的是，BlueButton这样的字眼放到代码中，一眼看过去谁知道是干什么的？

从上面的故事我们学到了：**组件的设计需要考虑到方方面面，对于组件的使用者来说，一眼看到组件的名字就需要告诉他，这个组件是干这件事的，别用错了！**

#参考
[http://insights.thoughtworks.cn/front-end-component-develop-and-application-in-react-native/](http://insights.thoughtworks.cn/front-end-component-develop-and-application-in-react-native/)

[https://v4-alpha.getbootstrap.com/components/buttons/](https://v4-alpha.getbootstrap.com/components/buttons/)

[https://reactjs.org/docs/higher-order-components.html](https://reactjs.org/docs/higher-order-components.html)

## 号外号外
最近在总结一些针对**Java**面试相关的知识点，感兴趣的朋友可以一起维护~  
地址：[https://github.com/xbox1994/2018-Java-Interview](https://github.com/xbox1994/2018-Java-Interview)
