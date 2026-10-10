/* ==========================================================================
   计算机网络刷题网站 v2 — 题库数据
   44 题（41 原题 + 3 道示例新题型 multi/sort/match）
   ========================================================================== */

const CATEGORIES = {
  arch:      '体系结构',
  phys:      '物理层',
  link:      '数据链路层',
  net:       '网络层与路由',
  transport: '传输层 TCP/UDP',
  app:       '应用层',
  device:    '设备与组网',
  reliable:  '差错与可靠传输',
  subnet:    '子网划分',
  nat:       'NAT 与 PPP'
};

const TYPE_LABEL = {
  single: '单选',
  tf:     '判断',
  fill:   '填空',
  short:  '简答',
  comp:   '综合',
  multi:  '多选',
  sort:   '排序',
  match:  '连线'
};

/* 类型选项顺序：用于筛选下拉 */
const TYPE_ORDER = ['single','multi','tf','fill','sort','match','short','comp'];

/* 默认 SRS 参数 */
const DEFAULT_SRS = () => ({ ef: 2.5, interval: 0, reps: 0, lapses: 0, due: 0, lastGrade: null });

/* ==========================================================================
   题库 — id 全局稳定唯一(从 q1 起,无论原 docx 题号是否重复)
   no 字段保留 docx 原题号,允许重复
   ========================================================================== */
const QUESTIONS = [
  // ========== 单选题 15 道 ==========
  {
    id:'q1',  no:24, type:'single', cat:'arch', diff:1,
    stem:'在 OSI 七层模型中，负责端到端可靠传输的层次是。',
    options:[{k:'A',t:'网络层'},{k:'B',t:'运输层'},{k:'C',t:'会话层'},{k:'D',t:'应用层'}],
    answer:['B'],
    explain:'运输层（传输层）提供端到端的可靠传输（TCP）或不可靠传输（UDP）。'
  },
  {
    id:'q2',  no:25, type:'single', cat:'phys', diff:2,
    stem:'以下关于奈奎斯特准则与香农定理说法正确的是。',
    options:[{k:'A',t:'奈奎斯特考虑信道噪声'},{k:'B',t:'香农定理仅适用于无噪声信道'},{k:'C',t:'奈奎斯特限制无噪声信道最高码元传输速率'},{k:'D',t:'香农公式与信道带宽无关'}],
    answer:['C'],
    explain:'奈奎斯特准则针对无噪声理想信道，给出极限码元速率；香农定理考虑噪声，给出极限信息传输速率，二者都与带宽有关。'
  },
  {
    id:'q3',  no:26, type:'single', cat:'link', diff:1,
    stem:'以太网采用的介质访问控制协议是。',
    options:[{k:'A',t:'CSMA/CD'},{k:'B',t:'CSMA/CA'},{k:'C',t:'TDMA'},{k:'D',t:'ALOHA'}],
    answer:['A'],
    explain:'有线以太网使用 CSMA/CD；无线局域网（WiFi）使用 CSMA/CA。'
  },
  {
    id:'q4',  no:27, type:'single', cat:'subnet', diff:2,
    stem:'子网掩码 255.255.255.224，每个子网可用主机数为。',
    options:[{k:'A',t:'30'},{k:'B',t:'32'},{k:'C',t:'62'},{k:'D',t:'64'}],
    answer:['A'],
    explain:'/27 子网：主机位 5 位，可用主机 = 2^5 − 2 = 30。'
  },
  {
    id:'q5',  no:28, type:'single', cat:'net', diff:1,
    stem:'下列地址中，属于私有 IP 地址的是。',
    options:[{k:'A',t:'11.12.13.14'},{k:'B',t:'172.20.5.8'},{k:'C',t:'202.99.1.2'},{k:'D',t:'128.10.1.1'}],
    answer:['B'],
    explain:'私有 IP 段：A 类 10.0.0.0/8，B 类 172.16.0.0/12（172.16–172.31），C 类 192.168.0.0/16。172.20.5.8 在 172.16–172.31 之间，属于 B 类私有。'
  },
  {
    id:'q6',  no:29, type:'single', cat:'transport', diff:2,
    stem:'TCP 滑动窗口机制主要为了解决。',
    options:[{k:'A',t:'拥塞控制'},{k:'B',t:'流量控制'},{k:'C',t:'差错检测'},{k:'D',t:'路由选择'}],
    answer:['B'],
    explain:'滑动窗口是接收方用于流量控制的机制；拥塞控制由慢启动、拥塞避免、快重传、快恢复组成。'
  },
  {
    id:'q7',  no:30, type:'single', cat:'reliable', diff:2,
    stem:'停止等待协议的信道利用率较低，主要原因是。',
    options:[{k:'A',t:'差错率太高'},{k:'B',t:'确认报文过长'},{k:'C',t:'信道空闲等待时间占比大'},{k:'D',t:'帧首部开销大'}],
    answer:['C'],
    explain:'停止等待协议每发一帧都要等 ACK 才发下一帧，信道大部分时间空闲。U = Td / (Td + RTT + Ta)。'
  },
  {
    id:'q8',  no:31, type:'single', cat:'app', diff:1,
    stem:'DNS 采用的运输层协议及默认端口是。',
    options:[{k:'A',t:'TCP 53'},{k:'B',t:'UDP 53'},{k:'C',t:'TCP 25'},{k:'D',t:'UDP 80'}],
    answer:['B'],
    explain:'DNS 默认 UDP 53，响应超 512 字节或区域传送时切换到 TCP 53。'
  },
  {
    id:'q9',  no:32, type:'single', cat:'subnet', diff:2,
    stem:'某主机 IP：192.168.5.130，子网掩码 255.255.255.128，其所在子网的网络地址是。',
    options:[{k:'A',t:'192.168.5.0'},{k:'B',t:'192.168.5.128'},{k:'C',t:'192.168.5.130'},{k:'D',t:'192.168.5.255'}],
    answer:['B'],
    explain:'/25 将 /24 划为两个子网 0–127 与 128–255，130 落在后者，网络地址 192.168.5.128。'
  },
  {
    id:'q10', no:33, type:'single', cat:'transport', diff:3,
    stem:'【docx 原题号 33 题干漏写题号,顺序推断】关于 TCP 拥塞控制的慢启动阶段，正确的是。',
    options:[{k:'A',t:'拥塞窗口线性增长'},{k:'B',t:'拥塞窗口指数增长，直到达到慢启动门限'},{k:'C',t:'仅在网络发生拥塞时执行'},{k:'D',t:'慢启动门限固定不变'}],
    answer:['B'],
    explain:'慢启动每收到一个 ACK cwnd 加倍，呈指数增长；达到 ssthresh 后进入拥塞避免（线性 +1/每 RTT）。'
  },
  {
    id:'q11', no:34, type:'single', cat:'nat', diff:2,
    stem:'下列关于 PPP 协议说法错误的是。',
    options:[{k:'A',t:'支持身份认证'},{k:'B',t:'既支持同步链路也支持异步链路'},{k:'C',t:'采用可靠传输机制保证无差错'},{k:'D',t:'由 LCP、NCP 和认证协议组成'}],
    answer:['C'],
    explain:'PPP 不可靠链路层协议，差错检测后直接丢弃，可靠性由上层保证。'
  },
  {
    id:'q12', no:35, type:'single', cat:'device', diff:1,
    stem:'路由器转发分组时，依据下列哪一项进行路由查表转发。',
    options:[{k:'A',t:'目的 MAC 地址'},{k:'B',t:'目的 IP 地址'},{k:'C',t:'源 IP 地址'},{k:'D',t:'源 MAC 地址'}],
    answer:['B'],
    explain:'路由器工作在网络层，依据目的 IP 地址查路由表转发。'
  },
  {
    id:'q13', no:36, type:'single', cat:'net', diff:1,
    stem:'下列哪种协议不属于网络层路由选择协议。',
    options:[{k:'A',t:'OSPF'},{k:'B',t:'RIP'},{k:'C',t:'BGP'},{k:'D',t:'FTP'}],
    answer:['D'],
    explain:'OSPF、RIP、BGP 是路由协议；FTP 是应用层文件传输协议。'
  },
  {
    id:'q14', no:37, type:'single', cat:'transport', diff:2,
    stem:'TCP 报文段首部中，用于连接建立与释放的控制位是。',
    options:[{k:'A',t:'PSH、URG'},{k:'B',t:'SYN、FIN'},{k:'C',t:'ACK、RST'},{k:'D',t:'PSH、ACK'}],
    answer:['B'],
    explain:'SYN 用于建立连接（三次握手），FIN 用于释放连接（四次挥手）。'
  },
  {
    id:'q15', no:38, type:'single', cat:'device', diff:2,
    stem:'网桥能够隔离网络的哪一类流量。',
    options:[{k:'A',t:'广播域流量'},{k:'B',t:'冲突域流量'},{k:'C',t:'路由转发流量'},{k:'D',t:'应用层会话流量'}],
    answer:['B'],
    explain:'网桥/交换机基于 MAC 地址转发，能隔离冲突域但不能隔离广播域；只有路由器才能隔离广播域。'
  },

  // ========== 判断题 10 道（docx 原题号 17–26,与单选题 24–26 撞号,no 保留） ==========
  {
    id:'q16', no:17, type:'tf', cat:'arch', diff:1,
    stem:'TCP/IP 四层体系结构中，网络接口层对应 OSI 模型的物理层和数据链路层。',
    answer:'T',
    explain:'TCP/IP 四层：应用层、传输层、网络层、网络接口层；网络接口层 ≈ 物理层 + 数据链路层。'
  },
  {
    id:'q17', no:18, type:'tf', cat:'phys', diff:1,
    stem:'香农定理计算的是无噪声信道的最高数据传输速率。',
    answer:'F',
    explain:'香农定理考虑噪声，给出有噪声信道的极限信息传输速率 C = W·log2(1+S/N)。'
  },
  {
    id:'q18', no:19, type:'tf', cat:'device', diff:1,
    stem:'以太网交换机可以隔离冲突域，但不能隔离广播域。',
    answer:'T',
    explain:'交换机每个端口是独立冲突域，但所有端口同属一个广播域；只有路由器能隔离广播域。'
  },
  {
    id:'q19', no:20, type:'tf', cat:'subnet', diff:1,
    stem:'192.168.1.0/24 网段中，网络地址和广播地址都不能分配给主机使用。',
    answer:'T',
    explain:'主机号全 0 为网络地址，全 1 为广播地址，两者均不能分配给主机。'
  },
  {
    id:'q20', no:21, type:'tf', cat:'transport', diff:1,
    stem:'UDP 是无连接协议，不提供差错检测和校验功能。',
    answer:'F',
    explain:'UDP 虽无连接，但首部有 16 位校验和字段，会对首部+数据做校验（可选）。'
  },
  {
    id:'q21', no:22, type:'tf', cat:'app', diff:1,
    stem:'HTTP 协议在传输层默认使用 TCP 80 端口。',
    answer:'T',
    explain:'HTTP 默认 80 端口；HTTPS 默认 443。'
  },
  {
    id:'q22', no:23, type:'tf', cat:'reliable', diff:2,
    stem:'停止等待协议属于可靠传输协议，不需要确认机制即可实现可靠传输。',
    answer:'F',
    explain:'停止等待协议正是靠确认 ACK + 超时重传实现可靠传输。'
  },
  {
    id:'q23', no:24, type:'tf', cat:'subnet', diff:2,
    stem:'子网掩码 255.255.255.192 划分的子网，每个子网可用主机数为 64。',
    answer:'F',
    explain:'/26 子网主机位 6 位，可用主机 = 2^6 − 2 = 62，不是 64。'
  },
  {
    id:'q24', no:25, type:'tf', cat:'transport', diff:2,
    stem:'TCP 慢启动阶段拥塞窗口呈线性增长，进入拥塞避免后变为指数增长。',
    answer:'F',
    explain:'反了：慢启动指数增长，达 ssthresh 后拥塞避免才线性增长。'
  },
  {
    id:'q25', no:26, type:'tf', cat:'nat', diff:1,
    stem:'PPP 协议具备差错恢复、流量控制和可靠传输的完整机制。',
    answer:'F',
    explain:'PPP 不可靠，差错检测后直接丢弃，不做重传/流量控制。'
  },

  // ========== 填空题 10 道 ==========
  {
    id:'q26', no:6, type:'fill', cat:'arch', diff:1,
    stem:'TCP/IP 体系结构中，负责端到端进程通信的层次是____。',
    blanks:[{ans:['运输层','传输层','Transport']}],
    explain:'运输层通过端口号标识进程，实现端到端进程间通信。'
  },
  {
    id:'q27', no:7, type:'fill', cat:'phys', diff:2,
    stem:'香农公式中，信道极限信息传输速率与信道带宽和____有关。',
    blanks:[{ans:['信噪比','S/N','信噪比(分贝)']}],
    explain:'C = W·log2(1+S/N)，与带宽 W 和信噪比 S/N 共同决定。'
  },
  {
    id:'q28', no:8, type:'fill', cat:'link', diff:1,
    stem:'以太网采用的介质访问控制方法是____。',
    blanks:[{ans:['CSMA/CD','载波监听多路访问/冲突检测']}],
    explain:'有线以太网用 CSMA/CD；无线 WiFi 用 CSMA/CA。'
  },
  {
    id:'q29', no:9, type:'fill', cat:'net', diff:1,
    stem:'IPv4 地址中，A 类私有地址的网段范围是____。',
    blanks:[{ans:['10.0.0.0～10.255.255.255','10.0.0.0/8','10.0.0.0-10.255.255.255']}],
    explain:'A 类私有：10.0.0.0/8；B 类：172.16.0.0/12；C 类：192.168.0.0/16。'
  },
  {
    id:'q30', no:10, type:'fill', cat:'subnet', diff:1,
    stem:'子网掩码 255.255.255.240，对应的主机位数为____位。',
    blanks:[{ans:['4','4 位','四']}],
    explain:'255.255.255.240 = /28，主机位 = 32−28 = 4。'
  },
  {
    id:'q31', no:11, type:'fill', cat:'transport', diff:2,
    stem:'TCP 实现可靠传输的核心机制是____和确认应答（ACK）。',
    blanks:[{ans:['超时重传','超时重传机制']}],
    explain:'TCP 可靠传输 = 校验和 + 序号 + 确认 + 超时重传 + 流量控制 + 拥塞控制。'
  },
  {
    id:'q32', no:12, type:'fill', cat:'transport', diff:2,
    stem:'TCP 拥塞控制四个阶段分别是：慢启动、____、快重传、快恢复。',
    blanks:[{ans:['拥塞避免','拥塞避免阶段']}],
    explain:'慢启动 → 拥塞避免 → 快重传 → 快恢复。'
  },
  {
    id:'q33', no:13, type:'fill', cat:'net', diff:1,
    stem:'路由器工作在网络层，依据____地址进行分组转发。',
    blanks:[{ans:['目的 IP','目的 IP 地址','目的IP地址']}],
    explain:'路由器查路由表，按目的 IP 匹配最长前缀转发。'
  },
  {
    id:'q34', no:14, type:'fill', cat:'app', diff:1,
    stem:'DNS 在绝大多数情况下运输层采用____协议。',
    blanks:[{ans:['UDP']}],
    explain:'为追求低时延，DNS 几乎都用 UDP。'
  },
  {
    id:'q35', no:15, type:'fill', cat:'nat', diff:1,
    stem:'数据链路层 PPP 协议中，负责链路配置与测试的协议是____。',
    blanks:[{ans:['LCP','链路控制协议']}],
    explain:'PPP = LCP（链路控制） + NCP（网络控制） + 认证协议。'
  },

  // ========== 简答题 4 道 ==========
  {
    id:'q36', no:1, type:'short', cat:'transport', diff:2,
    stem:'简述 TCP 与 UDP 协议的主要区别，以及各自适用的应用场景。',
    refAnswer:'连接特性：TCP 面向连接；UDP 无连接。\n可靠性：TCP 可靠传输；UDP 不可靠。\n开销与速率：TCP 首部开销大、效率低；UDP 首部简洁、时延小。\n应用场景：TCP 适用于文件/网页/邮件；UDP 适用于直播/语音/游戏/DNS。',
    points:[
      {key:'连接',text:'TCP 面向连接；UDP 无连接。',score:1},
      {key:'可靠性',text:'TCP 可靠；UDP 不可靠。',score:1},
      {key:'开销',text:'TCP 首部大、效率低；UDP 首部小、效率高、时延小。',score:1},
      {key:'应用',text:'TCP 适合文件/网页/邮件；UDP 适合直播/语音/游戏/DNS。',score:2}
    ],
    explain:'记忆口诀："TCP 稳，UDP 快"；"TCP 商务，UDP 直播"。'
  },
  {
    id:'q37', no:2, type:'short', cat:'device', diff:2,
    stem:'简述交换机与路由器的工作层次、转发依据及核心作用区别。',
    refAnswer:'工作层次：交换机数据链路层；路由器网络层。\n转发依据：交换机依据 MAC；路由器依据 IP。\n域隔离：交换机隔离冲突域；路由器隔离广播域、划分网段。\n主要作用：交换机局域内高速通信；路由器不同网段互联。',
    points:[
      {key:'层次',text:'交换机数据链路层；路由器网络层。',score:1},
      {key:'依据',text:'交换机按 MAC；路由器按 IP。',score:1},
      {key:'域隔离',text:'交换机隔离冲突域；路由器隔离广播域、划分网段。',score:2},
      {key:'作用',text:'交换机局域内高速通信；路由器不同网段互联。',score:1}
    ],
    explain:'记忆：交换 = "MAC + 链路层 + 冲突域"；路由 = "IP + 网络层 + 广播域"。'
  },
  {
    id:'q38', no:3, type:'short', cat:'reliable', diff:2,
    stem:'简述停止等待协议的工作原理，并说明该协议存在的主要缺点。',
    refAnswer:'工作原理：发送方每发送一帧后停止发送，等待 ACK；收到确认后再发下一帧；超时未收到确认则重传。\n主要缺点：信道利用率极低，大部分时间空闲；仅适合低速率、短时延的简单通信场景。',
    points:[
      {key:'原理',text:'发一帧 → 等 ACK → 收到再发；超时重传。',score:3},
      {key:'缺点',text:'信道利用率极低，仅适合低速短时延场景。',score:2}
    ],
    explain:'信道利用率 U = Td / (Td + RTT + Ta)；批量传输用滑动窗口/流水线协议（GBN、SR）改善。'
  },
  {
    id:'q39', no:4, type:'short', cat:'subnet', diff:1,
    stem:'简述划分子网的目的与子网划分带来的好处。',
    refAnswer:'划分子网目的：合理利用 IPv4 有限地址资源，对大型网络进行逻辑分段管理。\n主要好处：\n① 缩小广播范围，减少网络内广播风暴带来的流量消耗；\n② 实现网络分层管理，方便部门、区域独立管控网络；\n③ 节约公网 IP 地址，提升地址使用效率；\n④ 提升网络安全性，不同子网之间可做访问隔离。',
    points:[
      {key:'目的',text:'合理利用 IPv4 有限地址资源，对大型网络逻辑分段管理。',score:1},
      {key:'缩广播',text:'缩小广播范围，减少广播风暴。',score:1},
      {key:'分层管理',text:'实现网络分层管理，方便部门/区域独立管控。',score:1},
      {key:'省 IP',text:'节约公网 IP 地址，提升使用效率。',score:1},
      {key:'安全',text:'提升安全性，不同子网可做访问隔离。',score:1}
    ],
    explain:'子网划分实质是"借主机位当网络位"。'
  },

  // ========== 综合应用 2 道 ==========
  {
    id:'q40', no:5, type:'comp', cat:'subnet', diff:3,
    stem:'某企业拥有网络地址块 192.168.10.0/24，现需划分 6 个子网，每个子网内至少容纳 25 台主机，内网路由器采用 RIP 动态路由协议，广域网链路采用 PPP 协议封装传输。内网主机通过浏览器访问外网 Web 站点，全程使用 TCP/IP 协议簇完成通信。',
    parts:[
      {no:'(1)',score:5,stem:'计算合理子网掩码、划分出 6 个子网，写出每个子网网络地址、可用主机 IP 范围。',
       refAnswer:'主机位最少 5 位（2^5−2=30 ≥ 25），子网位 8−5=3 位，可划 2^3=8 个子网。\n子网掩码：255.255.255.224（/27）\n子网 1：192.168.10.0  可用：192.168.10.1 – 192.168.10.30\n子网 2：192.168.10.32 可用：192.168.10.33 – 192.168.10.62\n子网 3：192.168.10.64 可用：192.168.10.65 – 192.168.10.94\n子网 4：192.168.10.96 可用：192.168.10.97 – 192.168.10.126\n子网 5：192.168.10.128 可用：192.168.10.129 – 192.168.10.158\n子网 6：192.168.10.160 可用：192.168.10.161 – 192.168.10.190',
       points:[{key:'位数',text:'主机位 5、子网位 3。',score:1},{key:'掩码',text:'255.255.255.224（/27）。',score:1},{key:'6 网络地址',text:'6 组子网网络地址正确。',score:2},{key:'主机范围',text:'6 组可用主机 IP 范围正确。',score:1}]},
      {no:'(2)',score:5,stem:'PPP 协议采用字节填充法实现透明传输，原始发送数据十六进制：7E 5D 7E 7D，写出字节填充后数据序列，并简述 PPP 字节填充规则。',
       refAnswer:'规则：\n① 帧标志 0x7E → 替换为 0x7D 0x5E\n② 转义字符 0x7D → 替换为 0x7D 0x5D\n③ 其余字符不变\n原始：7E 5D 7E 7D\n填充后：7D 5E  7D 5D  7D 5E  7D 5D',
       points:[{key:'规则1',text:'0x7E → 0x7D 0x5E。',score:1},{key:'规则2',text:'0x7D → 0x7D 0x5D。',score:1},{key:'结果',text:'填充后结果正确：7D 5E 7D 5D 7D 5E 7D 5D。',score:2},{key:'规范',text:'书写规范。',score:1}]},
      {no:'(3)',score:5,stem:'简述内网主机访问外网 Web 服务器时，ARP 寻址 + TCP 三次握手 + HTTP 请求完整通信流程。',
       refAnswer:'① 主机先查本地 DNS 缓存，无结果则向本地 DNS 服务器发起递归查询，获取 Web 服务器 IP。\n② 主机判断目标 IP 不在同一内网，发送 ARP 请求获取网关路由器 MAC 地址。\n③ 主机与 Web 服务器完成 TCP 三次握手：SYN → SYN+ACK → ACK。\n④ 连接建立后，主机发送 HTTP 请求报文（GET /）。\n⑤ 服务器返回 HTTP 响应报文，传输网页数据；通信结束后四次挥手断开连接。',
       points:[{key:'DNS',text:'本地 DNS 缓存 / 递归解析。',score:1},{key:'ARP',text:'跨网段时 ARP 解析网关 MAC。',score:1},{key:'3次握手',text:'SYN / SYN+ACK / ACK 描述完整。',score:2},{key:'HTTP',text:'GET 请求 → 响应 → 四次挥手。',score:1}]}
    ]
  },
  {
    id:'q41', no:6, type:'comp', cat:'nat', diff:3,
    stem:'某小型企业内网规划网段为 192.168.3.0/24，企业仅申请到一个公网 IP 地址：203.10.6.8，企业出口路由器开启 PAT 端口多路复用 NAT 功能实现全体内网主机上网。内网主机通过浏览器访问外网服务器 IP：112.56.22.99。',
    parts:[
      {no:'(1)',score:5,stem:'写出私有 IP 地址三大网段范围，并简述静态 NAT、动态 NAT、PAT 三种 NAT 方式核心区别。',
       refAnswer:'A 类私有：10.0.0.0 – 10.255.255.255\nB 类私有：172.16.0.0 – 172.31.255.255\nC 类私有：192.168.0.0 – 192.168.255.255\n区别：\n① 静态 NAT：一对一固定映射，适合服务器发布。\n② 动态 NAT：多对多映射，从公网池自动分配。\n③ PAT：多对一映射，按端口号区分。',
       points:[{key:'3 段',text:'三类私有 IP 段完整写出。',score:2},{key:'静态',text:'静态 NAT 一对一固定映射。',score:1},{key:'动态',text:'动态 NAT 多对多、从公网池分配。',score:1},{key:'PAT',text:'PAT 多对一、按端口号区分。',score:1}]},
      {no:'(2)',score:5,stem:'结合本题场景，详细描述内网主机主动访问外网服务器时，数据包出内网、回传内网两次 NAT 地址与端口转换全过程。',
       refAnswer:'设：内网主机 192.168.3.10:50010；外网服务器 112.56.22.99:80；路由器公网 IP 203.10.6.8。\n外出：内网报文 (src=192.168.3.10:50010, dst=112.56.22.99:80) → 路由器把 src IP 替换为 203.10.6.8，并把 src 端口替换为公网唯一端口 P，记录映射。\n回传：外网返回 (dst=203.10.6.8:P) → 路由器查 NAT 映射表，把 dst IP/端口改回 192.168.3.10:50010，转发到内网。',
       points:[{key:'端口区分',text:'PAT 靠端口号区分不同内网主机。',score:1},{key:'外出',text:'外出时 src IP/端口替换为公网 IP+端口。',score:2},{key:'回传',text:'回传时查表反解 dst IP/端口并转发。',score:2}]},
      {no:'(3)',score:5,stem:'简述 NAT 技术的主要优点，以及 NAT 存在的局限性与缺点。',
       refAnswer:'优点：\n① 节约公网 IPv4 地址；\n② 隐藏内网真实 IP；\n③ 内网地址可自由规划，组网灵活。\n缺点：\n① 破坏端到端通信；\n② 增加路由器转发开销和时延；\n③ 部分内嵌 IP 的应用层协议异常；\n④ 不利于外网对内网设备远程管理。',
       points:[{key:'优点',text:'答对 2 条核心优点。',score:2},{key:'缺点',text:'答对 3 条主要缺点。',score:3}]}
    ]
  },

  // ========== 新题型示例：多选 / 排序 / 连线（v2 扩展） ==========
  {
    id:'q42', no:39, type:'multi', cat:'transport', diff:2,
    stem:'下列哪些是 TCP 可靠传输机制（多选）。',
    options:[
      {k:'A',t:'三次握手建立连接'},
      {k:'B',t:'校验和'},
      {k:'C',t:'滑动窗口'},
      {k:'D',t:'无连接立即发送'}
    ],
    answer:['A','B','C'],
    explain:'A 建立连接、B 校验和、C 滑动窗口 都是可靠传输机制；D 是 UDP 特征。'
  },
  {
    id:'q43', no:40, type:'sort', cat:'transport', diff:2,
    stem:'按 TCP 三次握手顺序排列下列报文。',
    sortItems:[
      {k:'A',t:'SYN（seq=x）'},
      {k:'B',t:'SYN+ACK（seq=y, ack=x+1）'},
      {k:'C',t:'ACK（seq=x+1, ack=y+1）'}
    ],
    sortKey:['A','B','C'],
    explain:'TCP 三次握手：客户端发 SYN → 服务端回 SYN+ACK → 客户端发 ACK。'
  },
  {
    id:'q44', no:41, type:'match', cat:'app', diff:1,
    stem:'将下列应用层协议与默认端口号连线。',
    matchPairs:[
      {left:'HTTP',   right:'80'},
      {left:'HTTPS',  right:'443'},
      {left:'DNS',    right:'53'},
      {left:'FTP',    right:'21'}
    ],
    explain:'HTTP=80、HTTPS=443、DNS=53、FTP=21（控制连接）。'
  }
];

/* 暴露给主脚本 */
if (typeof window !== 'undefined') {
  window.QUESTIONS = QUESTIONS;
  window.CATEGORIES = CATEGORIES;
  window.TYPE_LABEL = TYPE_LABEL;
  window.TYPE_ORDER = TYPE_ORDER;
  window.DEFAULT_SRS = DEFAULT_SRS;
}