pragma solidity ^0.4.0;

// 用户注册合约
contract Register {
    // 用户信息结构体
    struct User {
        address addr; // User地址
        address uscAddr; // USC地址
	    string username; // 用户名
	    bytes32 password; // 密码
	    string profile; // 简介
	    uint registerTime; // 注册时间
	    uint processTaskNum; // 进行中的任务数量
	    uint finishTaskNum; // 已完成的任务数量
	    uint reputation; // 信誉
    }
    // 管理员地址
    address owner;
    // 注册总上限
    uint maxRegistrants = 100000;
    // 注册总人数
    uint numRegistrants = 0;
    // 用户总信誉
    uint allReputation = 0;
    // 地址总列表
    address[] addrList;
    // 任务总列表
    address[] rwrcList;
    // username => User struct
    mapping(string => User) userPool;
    // username => USC addr
    mapping(string => address) uscPool;
    
    // Register构造函数
    function Register() {
        owner = msg.sender;
    }
    
    // 用户登录
    function login(string username, string password) returns (bool) {
        // 密码是否正确
        return userPool[username].password == keccak256(password);
    }
    
    // 检查注册
    function checkRegister(address addr, string username) returns (bool) {
		// 一个地址只能注册一次
		for(uint i = 0; i < addrList.length; ++i)
            if(addrList[i] == addr)
                return true;
		// 一个用户名只能注册一次
		return uscPool[username] != address(0);
    }
    
	// 用户注册
    function register(address addr, string username, string password, string profile) {
        // 统一管理
        if(msg.sender != owner)
            throw;
        // 人数上限
        if(numRegistrants > maxRegistrants)
            throw;
        // 检查注册
        if(checkRegister(addr, username))
            throw;
		// new USC
		UserSummary usc = new UserSummary();
	    // add to uscPool
	    uscPool[username] = usc;
		// add to userPool
		userPool[username] = User(addr, usc, username, keccak256(password), profile, now, 0, 0, 60);
		// add to addrList
		addrList.push(addr);
		// 注册总人数加1
		++numRegistrants;
		// 初始信誉默认60
		allReputation += 60;
    }
    
    // 获取用户信息
    function getUserInfo(string username) returns (address, address, string, uint, uint, uint, uint) {
        return (userPool[username].addr, userPool[username].uscAddr, userPool[username].profile, 
        userPool[username].registerTime, userPool[username].processTaskNum, 
        userPool[username].finishTaskNum, userPool[username].reputation);
    }
    
    // 更新密码
    function updatePassword(string username, string newPwd) {
		// 统一管理
		if(msg.sender != owner)
            throw;
        // keccak256加密
		userPool[username].password = keccak256(newPwd);
    }
    
    // 更新简介
    function updateProfile(string username, string profile) {
        // 统一管理
		if(msg.sender != owner)
            throw;
		// 直接更新
		userPool[username].profile = profile;
    }

    // 获取已发布的任务列表长度
    function getTaskListLength() returns (uint) {
        return rwrcList.length;
    }
    
    // 获取已发布的任务地址
    function getTaskAddr(uint i) returns (address) {
        return rwrcList[i];
    }
    
    //////////
    
    // 获取管理员地址 测试调用
    function getGMAddr() returns (address) {
        return owner;
    }
    
    // 检查用户名和地址的对应关系 RWRC调用
    function checkAddr(string username, address addr) returns (bool) {
        return userPool[username].addr == addr;
    }
    
    // 获取平均信誉 RWRC调用
    function getReputationAvg() returns (uint) {
        return allReputation / numRegistrants;
    }
    
    // 获取用户信誉 RWRC调用
    function getUserReputation(string username) returns (uint) {
        return userPool[username].reputation;
    }
    
    // 更新用户信誉 RWRC调用
    function updateUserReputation(string username, uint rep) {
        // 未注册
        if(uscPool[username] == address(0))
            throw;
        // 信誉范围
        if(rep < 0 || rep > 100)
            throw;
        // 安全保证
        for(uint i = 0; i < rwrcList.length; ++i) {
            if(msg.sender == rwrcList[i]) {
                allReputation += (rep - userPool[username].reputation);
                userPool[username].reputation= rep;
                break;
            }
        }
    }
    
    // 更新用户已完成的任务数量 RWRC调用
    function updateFinishTaskNum(string username) {
        // 未注册
        if(uscPool[username] == address(0))
            throw;
        // 安全保证
        for(uint i = 0; i < rwrcList.length; ++i) {
            if(msg.sender == rwrcList[i]) {
                // 进行中的任务数量减1
                --userPool[username].processTaskNum;
                // 已完成的任务数量加1
                ++userPool[username].finishTaskNum;
                break;
            }
        }
    }
    
    // 添加到已发送的任务列表 RWRC调用
    function addPostTask(string username) {
        // 安全保证
        if(uscPool[username] == address(0))
            throw;
        address rwrc = msg.sender;
        // 添加到任务总列表
        rwrcList.push(rwrc);
        // 添加到已发布的任务列表
        UserSummary(uscPool[username]).addPostTask(rwrc);
    }
    
    // 添加到已接受的任务列表 RWRC调用
    function addReceiveTask(string username) {
        // 安全保证
        for(uint i = 0; i < rwrcList.length; ++i) {
            if(msg.sender == rwrcList[i]) {
                // 进行中的任务数量加1
                ++userPool[username].processTaskNum;
                // 添加到已接收的任务列表
                UserSummary(uscPool[username]).addReceiveTask(rwrcList[i]);
                break;
            }
        }
    }
    
    // protect
    function () {
	    throw;
	}
}

// 用户汇总合约
contract UserSummary {
    // Register地址
    address reg;
    // 发布任务列表RWRC
    address[] postTaskList;
    // 接收任务列表RWRC
    address[] receiveTaskList;
    
    // UserSummary构造函数
    function UserSummary() {
        reg = msg.sender;
    }
    
    // 获取用户已发布的任务列表长度
    function getPostTaskLength() returns (uint) {
        return postTaskList.length;
    }
    
    // 获取用户已发布的任务地址
    function getPostTaskAddr(uint i) returns (address) {
        return postTaskList[i];
    }
    
    // 获取用户已接收的任务列表长度
    function getReceiveTaskLength() returns (uint) {
        return receiveTaskList.length;
    }
    
    // 获取用户已接收的任务地址
    function getReceiveTaskAddr(uint i) returns (address)  {
        return receiveTaskList[i];
    }
    
    //////////
    
    // 发布任务 Reg调用
    function addPostTask(address rwrc) {
        // 安全保证
        if(msg.sender != reg)
            throw;
        // 添加到已发布的任务列表
        postTaskList.push(rwrc);
    }
    
    // 接收任务 Reg调用
    function addReceiveTask(address rwrc) {
        // 安全保证
        if(msg.sender != reg)
            throw;
        // 添加到已接受的任务列表
        receiveTaskList.push(rwrc);
    }
    
    // protect
    function () {
	    throw;
	}
}

// 发布者-工作者合约
contract RequesterWorkerRelationship {
    // Task struct
    struct Task {
        string desc; // 描述
        uint reward; // 奖励
        uint deposit; // 押金
        uint deadline; // 截止时间
        uint maxNum; // 工作者上限数量
        uint nowNum; // 工作者当前数量
        uint minReputation; // 最小信誉
        uint ttype; // 任务类型
        Status status; // 任务状态
        string pointer; // 附件指针
    }
    // Worker struct
    struct Worker {
        address workerAddr; // 工作者地址
        string workerName; // 工作者名字
        string solution; // 答案描述
        string pointer; // 附件指针
        uint time; // 提交时间
        uint level; // 评估等级
    }
    // Status for worker
    enum Status {
        Pending, // 0 等待......
        Unclaimed, // 1 未领取完
        Claimed, // 2 已领取完
        Evaluating, // 3 评估中
        Completed // 4 已完成
	}
	// Register合约
	Register reg;
    // 管理员地址
    address gmAddr;
    // 发布者地址
    address ownerAddr;
    // 发布者名字
    string ownerName;
    // 合约任务
    Task task;
    // 工作者列表
    Worker[] workerList;
    // 已提交答案数量
    uint submitNum = 0;
    // 已评估答案数量
    uint evaluateNum = 0;
    
    // RequesterWorkerRelationship构造函数 发布任务
    function RequesterWorkerRelationship(address regAddr, address _gmAddr, string _ownerName, string desc, 
        uint deposit, uint deadline, uint maxNum, uint minReputation, uint ttype, string pointer) payable {
        reg = Register(regAddr); // reg
        gmAddr = _gmAddr;
        ownerAddr = msg.sender; // sender
        ownerName = _ownerName;
        // 检查用户名和地址的对应关系
        if(!reg.checkAddr(ownerName, ownerAddr))
            throw;
        task.desc = desc;
        task.reward = msg.value; // value
        task.deposit = deposit;
        task.deadline = deadline;
        task.maxNum = maxNum;
        task.nowNum = 0;
        task.minReputation = minReputation;
        task.ttype = ttype;
        task.status = Status.Unclaimed;
        task.pointer = pointer;
        // 添加到已发布的任务列表
        reg.addPostTask(ownerName);
    }
    
    // 获取任务信息 desc reward deposit deadline maxNum nowNum minReputation status pointer
    function getTaskInfo() returns (string, uint, uint, uint, uint, uint, uint, uint, Status, string) {
        // 更新任务状态
        updateStatus();
        return (task.desc, task.reward, task.deposit, task.deadline, task.maxNum, task.nowNum,
                    task.minReputation, task.ttype, task.status, task.pointer);
    }
    
    // 是否已接收
    function isReceive(string workerName) returns (bool) {
        // 判断是否为发布者
        if(equal(ownerName, workerName))
            return true;
        // 判断是否为工作者
        for(uint i = 0; i < workerList.length; ++i)
            if(equal(workerList[i].workerName, workerName))
                return true;
        return false;
    }
    
    // 检查工作者
    function checkWorker(string workerName) returns (bool) {
        // 任务时间
        if(now >= task.deadline)
            return false;
        // 任务状态
        if(task.status != Status.Unclaimed)
            return false;
        // 接收者押金
        if(msg.sender.balance < task.deposit)
            return false;
        // 接收者信誉
        if(reg.getUserReputation(workerName) < task.minReputation)
            return false;
        return true;
    }
    
    // 工作者接收任务 payable
    function receiveTask(string workerName) payable {
        // 检查条件
        if(isReceive(workerName) || !checkWorker(workerName))
            throw;
        // 金币不足
        if(msg.value < task.deposit)
            throw;
        // new Worker
        workerList.push(Worker(msg.sender, workerName, "", "", 0, 0));
        // 添加到已接收的任务列表
        reg.addReceiveTask(workerName);
        // 更新当前数量
        ++task.nowNum;
        // 更新任务状态
        updateStatus();
    }
    
    // 工作者提交答案
    function submitSolution(string workerName, string solution, string pointer) {
        // 统一管理
        if(msg.sender != gmAddr)
            throw;
        // 超出时间
        if(now >= task.deadline)
            throw;
        // 是否存在
        uint id = findWorkerId(workerName);
        if(id == 65535)
            throw;
        workerList[id].time = now;
        workerList[id].solution = solution;
        workerList[id].pointer = pointer;
        // 更新提交数量
        ++submitNum;
        // 更新任务状态
        updateStatus();
    }
    
    // 发布者评估答案
    function evaluateSolution(uint id, uint level) {
        // 统一管理
        if(msg.sender != gmAddr)
            throw;
        // 评估不等于0说明已评估
        if(workerList[id].level != 0)
            throw;
        // 评估等级
        workerList[id].level = level;
        // 接下来的思想来源某论文结论......
        string workerName = workerList[id].workerName;
        uint rep = reg.getUserReputation(workerName);
        // 计算奖励
        uint sendReward = task.deposit;
        // 平均奖励
        uint reward = task.reward / task.maxNum;
        // 高评估 高信誉 => 加信誉 + 奖励
        if (level >= 5 && rep >= reg.getReputationAvg()) {
            reg.updateUserReputation(workerName, rep + 1);
            sendReward += reward;
        }
        // 低评估 高信誉 => 减信誉
        else if (level < 5 && rep >= reg.getReputationAvg() + 1) {
            reg.updateUserReputation(workerName, rep - 1);
        }
        // 低评估 平均信誉 => 阈值
        else if (level < 5 && rep == reg.getReputationAvg()) {
            reg.updateUserReputation(workerName, 60);
        }
        // 低信誉 => 加信誉
        else if (rep < reg.getReputationAvg()){
            reg.updateUserReputation(workerName, rep + 1);
        }
        // 发送奖励
        workerList[id].workerAddr.transfer(sendReward);
        // 更新数量
        reg.updateFinishTaskNum(workerName);
        // 更新评估数量
        ++evaluateNum;
        // 更新任务状态
        updateStatus();
    }
    
    // 获取答案数量
    function getSolutionLength() returns (uint) {
        return workerList.length;
    }
    
    // 获取答案信息 workerName solution pointer time level
    function getSolution(uint i) returns (string, string, string, uint, uint) {
        return (workerList[i].workerName, workerList[i].solution, 
            workerList[i].pointer, workerList[i].time, workerList[i].level);
    }
    
    // 返还合约金币
    function kill() {
        // 统一管理
        if(msg.sender != gmAddr)
            throw;
        // 更新任务状态
        updateStatus();
        // 完成操作
        if(task.status == Status.Completed)
        {
            // 返还金币
            ownerAddr.transfer(this.balance);
        }
    }
    
    //////////
    
    // 更新任务状态 内部调用
    function updateStatus() private returns (Status) {
        task.status = Status.Pending; // 0 等待......
        // 未满人数 && 未到时间
        if(task.nowNum < task.maxNum && now <= task.deadline)
            task.status = Status.Unclaimed; // 1 未领取完
        // 已满人数 && 未到时间
        if(task.nowNum == task.maxNum && now <= task.deadline)
            task.status = Status.Claimed; // 2 已领取完
        // 评估未完 && 到达时间
        if(submitNum > evaluateNum && now >= task.deadline)
            task.status = Status.Evaluating; // 3 评估中
        // (评估完毕 && 到达时间) || (评估完毕 && 到达人数)
        if((submitNum == evaluateNum && now >= task.deadline) || 
            (submitNum == evaluateNum && evaluateNum == task.maxNum))
            task.status = Status.Completed; // 4 已完成
    }
    
    // 查找工作者id 内部调用
    function findWorkerId(string workerName) private returns (uint) {
        for(uint i = 0; i < workerList.length; ++i)
            if(equal(workerList[i].workerName, workerName))
                return i;
        return 65535;
    }
    
    // 判断两个字符串是否相等
    function equal(string _a, string _b) private returns (bool) {
        bytes memory a = bytes(_a);
        bytes memory b = bytes(_b);
        uint minLength = a.length;
        if (b.length < minLength) minLength = b.length;
        for (uint i = 0; i < minLength; i ++)
            if (a[i] != b[i])
                return false;
        return a.length == b.length;
    }
    
    // protect
    function () {
	    throw;
	}
}