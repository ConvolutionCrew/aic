from setuptools import find_packages, setup

package_name = "my_aic_policy"

setup(
    name=package_name,
    version="0.0.1",
    packages=find_packages(exclude=["test"]),
    data_files=[
        ("share/ament_index/resource_index/packages", ["resource/" + package_name]),
        ("share/" + package_name, ["package.xml"]),
    ],
    install_requires=["setuptools"],
    zip_safe=True,
    maintainer="You",
    maintainer_email="you@example.com",
    description="Starter policy package for the AI for Industry Challenge",
    license="Apache-2.0",
    extras_require={
        "test": [
            "pytest",
        ],
    },
)
