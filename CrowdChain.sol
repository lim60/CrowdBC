pragma solidity ^0.4.0;

// �û�ע���Լ
contract Register {
    // �û���Ϣ�ṹ��
    struct User {
        address addr; // User��ַ
        address uscAddr; // USC��ַ
	    string username; // �û���
	    bytes32 password; // ����
	    string profile; // ���
	    uint registerTime; // ע��ʱ��
	    uint processTaskNum; // �����е���������
	    uint finishTaskNum; // ����ɵ���������
	    uint reputation; // ����
    }
    // ����Ա��ַ
    address owner;
    // ע��������
    uint maxRegistrants = 100000;
    // ע��������
    uint numRegistrants = 0;
    // �û�������
    uint allReputation = 0;
    // ��ַ���б�
    address[] addrList;
    // �������б�
    address[] rwrcList;
    // username => User struct
    mapping(string => User) userPool;
    // username => USC addr
    mapping(string => address) uscPool;
    
    // Register���캯��
    function Register() {
        owner = msg.sender;
    }
    
    // �û���¼
    function login(string username, string password) returns (bool) {
        // �����Ƿ���ȷ
        return userPool[username].password == keccak256(password);
    }
    
    // ���ע��
    function checkRegister(address addr, string username) returns (bool) {
		// һ����ַֻ��ע��һ��
		for(uint i = 0; i < addrList.length; ++i)
            if(addrList[i] == addr)
                return true;
		// һ���û���ֻ��ע��һ��
		return uscPool[username] != address(0);
    }
    
	// �û�ע��
    function register(address addr, string username, string password, string profile) {
        // ͳһ����
        if(msg.sender != owner)
            throw;
        // ��������
        if(numRegistrants > maxRegistrants)
            throw;
        // ���ע��
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
		// ע����������1
		++numRegistrants;
		// ��ʼ����Ĭ��60
		allReputation += 60;
    }
    
    // ��ȡ�û���Ϣ
    function getUserInfo(string username) returns (address, address, string, uint, uint, uint, uint) {
        return (userPool[username].addr, userPool[username].uscAddr, userPool[username].profile, 
        userPool[username].registerTime, userPool[username].processTaskNum, 
        userPool[username].finishTaskNum, userPool[username].reputation);
    }
    
    // ��������
    function updatePassword(string username, string newPwd) {
		// ͳһ����
		if(msg.sender != owner)
            throw;
        // keccak256����
		userPool[username].password = keccak256(newPwd);
    }
    
    // ���¼��
    function updateProfile(string username, string profile) {
        // ͳһ����
		if(msg.sender != owner)
            throw;
		// ֱ�Ӹ���
		userPool[username].profile = profile;
    }

    // ��ȡ�ѷ����������б���
    function getTaskListLength() returns (uint) {
        return rwrcList.length;
    }
    
    // ��ȡ�ѷ����������ַ
    function getTaskAddr(uint i) returns (address) {
        return rwrcList[i];
    }
    
    //////////
    
    // ��ȡ����Ա��ַ ���Ե���
    function getGMAddr() returns (address) {
        return owner;
    }
    
    // ����û����͵�ַ�Ķ�Ӧ��ϵ RWRC����
    function checkAddr(string username, address addr) returns (bool) {
        return userPool[username].addr == addr;
    }
    
    // ��ȡƽ������ RWRC����
    function getReputationAvg() returns (uint) {
        return allReputation / numRegistrants;
    }
    
    // ��ȡ�û����� RWRC����
    function getUserReputation(string username) returns (uint) {
        return userPool[username].reputation;
    }
    
    // �����û����� RWRC����
    function updateUserReputation(string username, uint rep) {
        // δע��
        if(uscPool[username] == address(0))
            throw;
        // ������Χ
        if(rep < 0 || rep > 100)
            throw;
        // ��ȫ��֤
        for(uint i = 0; i < rwrcList.length; ++i) {
            if(msg.sender == rwrcList[i]) {
                allReputation += (rep - userPool[username].reputation);
                userPool[username].reputation= rep;
                break;
            }
        }
    }
    
    // �����û�����ɵ��������� RWRC����
    function updateFinishTaskNum(string username) {
        // δע��
        if(uscPool[username] == address(0))
            throw;
        // ��ȫ��֤
        for(uint i = 0; i < rwrcList.length; ++i) {
            if(msg.sender == rwrcList[i]) {
                // �����е�����������1
                --userPool[username].processTaskNum;
                // ����ɵ�����������1
                ++userPool[username].finishTaskNum;
                break;
            }
        }
    }
    
    // ��ӵ��ѷ��͵������б� RWRC����
    function addPostTask(string username) {
        // ��ȫ��֤
        if(uscPool[username] == address(0))
            throw;
        address rwrc = msg.sender;
        // ��ӵ��������б�
        rwrcList.push(rwrc);
        // ��ӵ��ѷ����������б�
        UserSummary(uscPool[username]).addPostTask(rwrc);
    }
    
    // ��ӵ��ѽ��ܵ������б� RWRC����
    function addReceiveTask(string username) {
        // ��ȫ��֤
        for(uint i = 0; i < rwrcList.length; ++i) {
            if(msg.sender == rwrcList[i]) {
                // �����е�����������1
                ++userPool[username].processTaskNum;
                // ��ӵ��ѽ��յ������б�
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

// �û����ܺ�Լ
contract UserSummary {
    // Register��ַ
    address reg;
    // ���������б�RWRC
    address[] postTaskList;
    // ���������б�RWRC
    address[] receiveTaskList;
    
    // UserSummary���캯��
    function UserSummary() {
        reg = msg.sender;
    }
    
    // ��ȡ�û��ѷ����������б���
    function getPostTaskLength() returns (uint) {
        return postTaskList.length;
    }
    
    // ��ȡ�û��ѷ����������ַ
    function getPostTaskAddr(uint i) returns (address) {
        return postTaskList[i];
    }
    
    // ��ȡ�û��ѽ��յ������б���
    function getReceiveTaskLength() returns (uint) {
        return receiveTaskList.length;
    }
    
    // ��ȡ�û��ѽ��յ������ַ
    function getReceiveTaskAddr(uint i) returns (address)  {
        return receiveTaskList[i];
    }
    
    //////////
    
    // �������� Reg����
    function addPostTask(address rwrc) {
        // ��ȫ��֤
        if(msg.sender != reg)
            throw;
        // ��ӵ��ѷ����������б�
        postTaskList.push(rwrc);
    }
    
    // �������� Reg����
    function addReceiveTask(address rwrc) {
        // ��ȫ��֤
        if(msg.sender != reg)
            throw;
        // ��ӵ��ѽ��ܵ������б�
        receiveTaskList.push(rwrc);
    }
    
    // protect
    function () {
	    throw;
	}
}

// ������-�����ߺ�Լ
contract RequesterWorkerRelationship {
    // Task struct
    struct Task {
        string desc; // ����
        uint reward; // ����
        uint deposit; // Ѻ��
        uint deadline; // ��ֹʱ��
        uint maxNum; // ��������������
        uint nowNum; // �����ߵ�ǰ����
        uint minReputation; // ��С����
        uint ttype; // ��������
        Status status; // ����״̬
        string pointer; // ����ָ��
    }
    // Worker struct
    struct Worker {
        address workerAddr; // �����ߵ�ַ
        string workerName; // ����������
        string solution; // ������
        string pointer; // ����ָ��
        uint time; // �ύʱ��
        uint level; // �����ȼ�
    }
    // Status for worker
    enum Status {
        Pending, // 0 �ȴ�......
        Unclaimed, // 1 δ��ȡ��
        Claimed, // 2 ����ȡ��
        Evaluating, // 3 ������
        Completed // 4 �����
	}
	// Register��Լ
	Register reg;
    // ����Ա��ַ
    address gmAddr;
    // �����ߵ�ַ
    address ownerAddr;
    // ����������
    string ownerName;
    // ��Լ����
    Task task;
    // �������б�
    Worker[] workerList;
    // ���ύ������
    uint submitNum = 0;
    // ������������
    uint evaluateNum = 0;
    
    // RequesterWorkerRelationship���캯�� ��������
    function RequesterWorkerRelationship(address regAddr, address _gmAddr, string _ownerName, string desc, 
        uint deposit, uint deadline, uint maxNum, uint minReputation, uint ttype, string pointer) payable {
        reg = Register(regAddr); // reg
        gmAddr = _gmAddr;
        ownerAddr = msg.sender; // sender
        ownerName = _ownerName;
        // ����û����͵�ַ�Ķ�Ӧ��ϵ
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
        // ��ӵ��ѷ����������б�
        reg.addPostTask(ownerName);
    }
    
    // ��ȡ������Ϣ desc reward deposit deadline maxNum nowNum minReputation status pointer
    function getTaskInfo() returns (string, uint, uint, uint, uint, uint, uint, uint, Status, string) {
        // ��������״̬
        updateStatus();
        return (task.desc, task.reward, task.deposit, task.deadline, task.maxNum, task.nowNum,
                    task.minReputation, task.ttype, task.status, task.pointer);
    }
    
    // �Ƿ��ѽ���
    function isReceive(string workerName) returns (bool) {
        // �ж��Ƿ�Ϊ������
        if(equal(ownerName, workerName))
            return true;
        // �ж��Ƿ�Ϊ������
        for(uint i = 0; i < workerList.length; ++i)
            if(equal(workerList[i].workerName, workerName))
                return true;
        return false;
    }
    
    // ��鹤����
    function checkWorker(string workerName) returns (bool) {
        // ����ʱ��
        if(now >= task.deadline)
            return false;
        // ����״̬
        if(task.status != Status.Unclaimed)
            return false;
        // ������Ѻ��
        if(msg.sender.balance < task.deposit)
            return false;
        // ����������
        if(reg.getUserReputation(workerName) < task.minReputation)
            return false;
        return true;
    }
    
    // �����߽������� payable
    function receiveTask(string workerName) payable {
        // �������
        if(isReceive(workerName) || !checkWorker(workerName))
            throw;
        // ��Ҳ���
        if(msg.value < task.deposit)
            throw;
        // new Worker
        workerList.push(Worker(msg.sender, workerName, "", "", 0, 0));
        // ��ӵ��ѽ��յ������б�
        reg.addReceiveTask(workerName);
        // ���µ�ǰ����
        ++task.nowNum;
        // ��������״̬
        updateStatus();
    }
    
    // �������ύ��
    function submitSolution(string workerName, string solution, string pointer) {
        // ͳһ����
        if(msg.sender != gmAddr)
            throw;
        // ����ʱ��
        if(now >= task.deadline)
            throw;
        // �Ƿ����
        uint id = findWorkerId(workerName);
        if(id == 65535)
            throw;
        workerList[id].time = now;
        workerList[id].solution = solution;
        workerList[id].pointer = pointer;
        // �����ύ����
        ++submitNum;
        // ��������״̬
        updateStatus();
    }
    
    // ������������
    function evaluateSolution(uint id, uint level) {
        // ͳһ����
        if(msg.sender != gmAddr)
            throw;
        // ����������0˵��������
        if(workerList[id].level != 0)
            throw;
        // �����ȼ�
        workerList[id].level = level;
        // ��������˼����Դĳ���Ľ���......
        string workerName = workerList[id].workerName;
        uint rep = reg.getUserReputation(workerName);
        // ���㽱��
        uint sendReward = task.deposit;
        // ƽ������
        uint reward = task.reward / task.maxNum;
        // ������ ������ => ������ + ����
        if (level >= 5 && rep >= reg.getReputationAvg()) {
            reg.updateUserReputation(workerName, rep + 1);
            sendReward += reward;
        }
        // ������ ������ => ������
        else if (level < 5 && rep >= reg.getReputationAvg() + 1) {
            reg.updateUserReputation(workerName, rep - 1);
        }
        // ������ ƽ������ => ��ֵ
        else if (level < 5 && rep == reg.getReputationAvg()) {
            reg.updateUserReputation(workerName, 60);
        }
        // ������ => ������
        else if (rep < reg.getReputationAvg()){
            reg.updateUserReputation(workerName, rep + 1);
        }
        // ���ͽ���
        workerList[id].workerAddr.transfer(sendReward);
        // ��������
        reg.updateFinishTaskNum(workerName);
        // ������������
        ++evaluateNum;
        // ��������״̬
        updateStatus();
    }
    
    // ��ȡ������
    function getSolutionLength() returns (uint) {
        return workerList.length;
    }
    
    // ��ȡ����Ϣ workerName solution pointer time level
    function getSolution(uint i) returns (string, string, string, uint, uint) {
        return (workerList[i].workerName, workerList[i].solution, 
            workerList[i].pointer, workerList[i].time, workerList[i].level);
    }
    
    // ������Լ���
    function kill() {
        // ͳһ����
        if(msg.sender != gmAddr)
            throw;
        // ��������״̬
        updateStatus();
        // ��ɲ���
        if(task.status == Status.Completed)
        {
            // �������
            ownerAddr.transfer(this.balance);
        }
    }
    
    //////////
    
    // ��������״̬ �ڲ�����
    function updateStatus() private returns (Status) {
        task.status = Status.Pending; // 0 �ȴ�......
        // δ������ && δ��ʱ��
        if(task.nowNum < task.maxNum && now <= task.deadline)
            task.status = Status.Unclaimed; // 1 δ��ȡ��
        // �������� && δ��ʱ��
        if(task.nowNum == task.maxNum && now <= task.deadline)
            task.status = Status.Claimed; // 2 ����ȡ��
        // ����δ�� && ����ʱ��
        if(submitNum > evaluateNum && now >= task.deadline)
            task.status = Status.Evaluating; // 3 ������
        // (������� && ����ʱ��) || (������� && ��������)
        if((submitNum == evaluateNum && now >= task.deadline) || 
            (submitNum == evaluateNum && evaluateNum == task.maxNum))
            task.status = Status.Completed; // 4 �����
    }
    
    // ���ҹ�����id �ڲ�����
    function findWorkerId(string workerName) private returns (uint) {
        for(uint i = 0; i < workerList.length; ++i)
            if(equal(workerList[i].workerName, workerName))
                return i;
        return 65535;
    }
    
    // �ж������ַ����Ƿ����
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