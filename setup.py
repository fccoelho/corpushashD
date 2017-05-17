from pyd.support import setup, Extension


projName = 'hello'

setup(
    name="corpushashD",
    version='0.1',
    ext_modules=[
        Extension('corpushash', ['source/corpushash/hashers.d'],
            extra_compile_args=['-w'],
            build_deimos=True,
            d_lump=True
        )
    ],
)
