[
  {
    # https://github.com/raspberrypi/linux/blob/rpi-6.12.y/arch/arm/boot/dts/overlays/disable-bt-overlay.dts
    name = "disable-bt";
    dtsText = ''
      /dts-v1/;
      /plugin/;

      #include <dt-bindings/gpio/gpio.h>

      / {
          compatible = "brcm,bcm2711";

          fragment@0 {
              target = <&uart1>;
              __overlay__ {
                  status = "disabled";
              };
          };

          fragment@1 {
              target = <&bt>;
              __overlay__ {
                  status = "disabled";
              };
          };
      };
    '';
  }

  {
    # https://github.com/raspberrypi/linux/blob/rpi-6.12.y/arch/arm/boot/dts/overlays/gpio-fan-overlay.dts
    name = "gpio-fan";
    dtsText = ''
      /dts-v1/;
      /plugin/;

      / {
          compatible = "brcm,bcm2711";

          fragment@0 {
              target-path = "/";
              __overlay__ {
                  fan0: gpio-fan@0 {
                      compatible = "gpio-fan";
                      gpios = <&gpio 14 0>;
                      gpio-fan,speed-map = <0    0>,
                                           <5000 1>;
                      #cooling-cells = <2>;
                  };
              };
          };

          fragment@1 {
              target = <&cpu_thermal>;
              polling-delay = <2000>; /* milliseconds */
              __overlay__ {
                  trips {
                      cpu_hot: trip-point@0 {
                          temperature = <60000>;  /* (millicelsius) Fan started at 60°C */
                          hysteresis = <10000>;   /* (millicelsius) Fan stopped at 50°C */
                          type = "active";
                      };
                  };
                  cooling-maps {
                      map0 {
                          trip = <&cpu_hot>;
                          cooling-device = <&fan0 1 1>;
                      };
                  };
              };
          };

          __overrides__ {
              gpiopin = <&fan0>,"gpios:4", <&fan0>,"brcm,pins:0";
              temp = <&cpu_hot>,"temperature:0";
          };
      };
    '';
  }
]
