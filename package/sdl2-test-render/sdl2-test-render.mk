SDL2_TEST_RENDER_VERSION = develop
SDL2_TEST_RENDER_SITE = https://git1.atb-e.ru/cpu_soft/build_systems/packages/sdl2-test-render.git
SDL2_TEST_RENDER_SITE_METHOD = git
SDL2_TEST_RENDER_DEPENDENCIES = sdl2

define SDL2_TEST_RENDER_BUILD_CMDS
	$(TARGET_CC) -o $(@D)/sdl2-test-render $(@D)/sdl2-test-render.c -lSDL2
endef

define SDL2_TEST_RENDER_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/sdl2-test-render $(TARGET_DIR)/usr/bin
endef

$(eval $(generic-package))
