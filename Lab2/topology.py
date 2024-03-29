#! /usr/bin/python
import time

from mininet.topo import Topo
from mininet.net import Mininet
from mininet.node import Node, Switch
from mininet.cli import CLI

class Router(Node):
    "Node with Linux Router Function"
    
    def config(self, **params):
        super(Router, self).config(**params)
        self.cmd('sysctl net.ipv4.ip_forward=1')

    def terminate(self):
        self.cmd('sysctl net.ipv4.ip_forward=0')
        super(Router, self).terminate()

def topology():
    net = Mininet(autoStaticArp=True)

    # Initialize objects dicts
    hosts, switches, routers = {}, {}, {}

    # Create Host, from h1 to h6
    for i in range(6):
        host = net.addHost('h%d' % (i + 1), ip="0.0.0.0/0", mac="00:00:00:00:00:0%d" % (i + 1))
        hosts['h%d' % (i + 1)] = host

    # Create DHCP server
    DHCPServer = net.addHost('DHCPServer')

    # Create Switch, from s1 to s3
    for i in range(3):
        switch = net.addSwitch('s%d' % (i + 1), failMode='standalone')
        switches['s%d' % (i + 1)] = switch

    # Create Router, from r1 to r4
    for i in range(4):
        router = net.addHost('r%d' % (i + 1), cls=Router)
        routers['r%d' % (i + 1)] = router

    # link pairs
    links = [('r2', 'r3'), ('r2', 'r1'),
             ('r3', 'r4'), ('r1', 's1'),
             ('r1', 's2'), ('r4', 's3'),
             ('s1', 'h1'), ('s1', 'h2'), 
             ('s1', 'DHCPServer'),
             ('s2', 'h3'), ('s2', 'h4'),
             ('s3', 'h5'), ('s3', 'h6')
             
            ]
    #create link
    for link in links:
        src, dst = link
        net.addLink(src, dst)

    net.start()

    # Configure network manually
    config(hosts, switches, routers, DHCPServer)

    # Run DHCP server at node DHCPserver
    runDHCP(net)

    check(hosts)

    # Comment this line if you don't need to debug
    CLI(net)
    
    check(hosts)
    # Kill DHCP server process, don't leave dhcp process on your computer 
    killDHCP(net)

    net.stop()

def config(hosts, switches, routers, DHCPServer):
    # Hosts interface IP and  default gateway configuration

    # Hosts, Routers interface IP configuration
    hosts['h3'].cmd('ip address add 192.168.1.129/25 dev h3-eth0')
    hosts['h4'].cmd('ip address add 192.168.1.130/25 dev h4-eth0')
    hosts['h5'].cmd('ip address add 192.168.3.2/24 dev h5-eth0')
    hosts['h6'].cmd('ip address add 192.168.3.3/24 dev h6-eth0')
    DHCPServer.cmd('ip address add 192.168.1.4/25 dev DHCPServer-eth0')

    # Config r1-r4 interface IP
    routers['r1'].cmd('ip address flush dev r1-eth0')
    routers['r2'].cmd('ip address flush dev r2-eth0')
    routers['r3'].cmd('ip address flush dev r3-eth0')
    routers['r4'].cmd('ip address flush dev r4-eth0')
    routers['r1'].cmd('ip address add 10.0.1.2/24 dev r1-eth0')
    routers['r1'].cmd('ip address add 192.168.1.126/25 dev r1-eth1')
    routers['r1'].cmd('ip address add 192.168.1.254/25 dev r1-eth2')
    routers['r2'].cmd('ip address add 10.0.0.1/24 dev r2-eth0')
    routers['r2'].cmd('ip address add 10.0.1.1/24 dev r2-eth1')
    routers['r3'].cmd('ip address add 10.0.0.2/24 dev r3-eth0')
    routers['r3'].cmd('ip address add 10.0.2.1/24 dev r3-eth1')
    routers['r4'].cmd('ip address add 10.0.2.3/24 dev r4-eth0')
    routers['r4'].cmd('ip address add 192.168.3.254/24 dev r4-eth1')

    # Host routing table and default gateway configuration
    hosts['h3'].cmd('ip route add default via 192.168.1.254 dev h3-eth0')
    hosts['h4'].cmd('ip route add default via 192.168.1.254 dev h4-eth0')
    hosts['h5'].cmd('ip route add default via 192.168.3.254 dev h5-eth0')
    hosts['h6'].cmd('ip route add default via 192.168.3.254 dev h6-eth0')

    # Config r1-r4 routing table rules
    # Router routing table configuration
    routers['r1'].cmd('ip route add default via 10.0.1.1')
    routers['r2'].cmd('ip route add 192.168.1.0/24 via 10.0.1.2')
    routers['r2'].cmd('ip route add 192.168.3.0/24 via 10.0.0.2')
    routers['r2'].cmd('ip route add 10.0.2.0/24 via 10.0.0.2')
    routers['r3'].cmd('ip route add 192.168.1.0/24 via 10.0.0.1')
    routers['r3'].cmd('ip route add 192.168.3.0/24 via 10.0.2.3')
    routers['r3'].cmd('ip route add 10.0.1.0/24 via 10.0.0.1')
    routers['r4'].cmd('ip route add default via 10.0.2.1')

def check(hosts):
    ips = {'192.168.1.129', '192.168.1.130', '192.168.3.2', '192.168.3.3'}
    flag = 0
    for h in sorted(hosts):
        for ip in sorted(ips):
            check = hosts[h].cmd('ping %s -c 1 -W 1' % ip)
            if '64 bytes from %s' %ip not in check:
                print('\033[93m%s doesn\'t have connectivity to %s\033[0m' % (h,ip))
                flag = 1
    if flag==0:
        print('\033[92mACCEPT\033[0m')
    if flag==1:
        print('\033[91mWRONG ANSWER\033[0m')

def runDHCP(net):
    #Run DHCP server on node DHCPServer
    print("[+] Run DHCP server")
    dhcp = net.getNodeByName('DHCPServer') 
    dhcp.cmdPrint('/usr/sbin/dhcpd 4 -pf /run/dhcp-server-dhcpd.pid -cf ./dhcpd.conf %s' % dhcp.defaultIntf())
    #print("[+] Run dhclient on h1")
    #h1 = net.getNodeByName('h1')
    #h1.cmdPrint("dhclient -pf /run/dhclient-h1-eth0.pid -v h1-eth0")
    #print("[+] Run dhclient on h2")
    #h2 = net.getNodeByName('h2')
    #h2.cmdPrint("dhclient -pf /run/dhclient-h2-eth0.pid -v h2-eth0")

def killDHCP(net):
    #Kill DHCP server process
    print("[-] Killing DHCP server")
    dhcp = net.getNodeByName('DHCPServer')
    dhcp.cmdPrint("kill -9 `ps aux | grep DHCPServer-eth0 | grep dhcpd | awk '{print $2}'`")
    print("[-] Release h1 DHCP")
    h1 = net.getNodeByName('h1')
    h1.cmdPrint("dhclient -r -pf /run/dhclient-h1-eth0.pid")
    print("[-] Release h2 DHCP")
    h2 = net.getNodeByName('h2')
    h2.cmdPrint("dhclient -r -pf /run/dhclient-h2-eth0.pid")

if __name__ == '__main__':
    topology()


