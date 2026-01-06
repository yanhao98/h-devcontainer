check_packages() {
    echo "Mock: check_packages $@"
}
apt_get_update() {
    echo "Mock: apt_get_update"
}
apt-get() {
    echo "Mock: apt-get $@"
}
dpkg-query() {
    return 0
}
dpkg() {
    return 0
}
locale-gen() {
    echo "Mock: locale-gen"
}
