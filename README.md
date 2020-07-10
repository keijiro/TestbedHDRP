TestbedHDRP
===========

![gif](https://i.imgur.com/2qlNtFC.gif)
![gif](https://i.imgur.com/K3k5ffi.gif)

![gif](https://i.imgur.com/m7lKcUh.gif)
![gif](https://i.imgur.com/p29Lrap.gif)

TestbedHDRP is a Unity project where I try custom effect ideas with
[Unity HDRP]. Currently, it only contains the following two types of effects:

- Geometry shader effects
- Many-light effects

Although the geometry shader effects are fun and exciting to use, I don't
recommend using them in production. **The geometry shader is near-obsolete
technology.** You will meet several problems if you use it in your product.

The many-light effects are mainly for benchmark purposes. I just wanted to know
how I could utilize the power of FPTL.

[Unity HDRP]:
  https://docs.unity3d.com/Packages/com.unity.render-pipelines.high-definition@latest

System requirements
-------------------

- Unity 2019.4
- HDRP 7.4
