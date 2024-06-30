const std = @import("std");

const Node = struct {
    value: u8 = 0,
    next: ?*Node = null,
    prev: ?*Node = null,
    pub fn new(v: u8, n: ?*Node, p: ?*Node) Node {
        return Node{ .value = v, .next = n, .prev = p };
    }
    pub fn getNext(self: Node) ?*Node {
        return self.next;
    }
    pub fn getPrev(self: Node) ?*Node {
        return self.prev;
    }
};

const ListErrors = error{
    ElementDNE,
    OutOfBounds,
};

const LinkedList = struct {
    head: ?*Node,
    tail: ?*Node,
    len: usize = 0,

    pub fn append(self: *LinkedList, new: *Node) void {
        if (self.head != null) {
            if (self.head.? != self.tail.?) {
                new.prev = self.tail;
                self.tail.?.next = new;
                self.tail.? = new;
            } else { //only 1 element
                new.prev = self.head;
                self.tail.? = new;
                self.head.?.next = self.tail;
            }
        } else {
            self.head = new;
            self.tail = new;
        }
        self.len += 1;
    }
    pub fn pop(self: *LinkedList) ?*Node {
        var end: ?*Node = null;
        if (self.head != null) {
            if (self.head.? != self.tail.?) {
                end = self.tail;
            } else { //only 1 element
                end = self.head;
                self.head = null;
            }
            self.tail = end.?.prev;
            end.?.prev.?.next = null;
            end.?.next = null;
            end.?.prev = null;
        }
        self.len -= 1;
        return end;
    }
    // pub fn insert(self: *LinkedList, new: *Node)

    pub fn print(self: LinkedList) void {
        var current: *Node = self.head orelse return;
        while (true) {
            std.debug.print("{}  ", .{current.value});
            current = current.next orelse break;
        }
        std.debug.print("\n", .{});
    }
    pub fn printBackwards(self: LinkedList) void {
        var current: *Node = self.tail orelse return;
        while (true) {
            std.debug.print("{}  ", .{current.value});
            current = current.prev orelse break;
        }
        std.debug.print("\n", .{});
    }
    pub fn count(self: LinkedList, val: u8) usize {
        var current: *Node = self.head orelse return 0;
        var counter: usize = 0;
        while (true) {
            if (current.value == val) counter += 1;
            current = current.next orelse break;
        }
        return counter;
    }

    pub fn reverse(self: *LinkedList) void {
        var current: *Node = self.head orelse return;
        while (true) {
            const temp = current.next;
            current.next = current.prev;
            current.prev = temp;
            current = temp orelse break;
        }
        const temp = self.head;
        self.head = self.tail;
        self.tail = temp;
    }
    pub fn remove(self: *LinkedList, val: u8) ListErrors!void {
        var current = self.head orelse return ListErrors.ElementDNE;
        while (true) {
            if (current.value == val) {
                if (self.head == self.tail) { //only element in list
                    self.head = null;
                    self.tail = null;
                } else if (current == self.head) {
                    self.head = current.next;
                    self.head.?.prev = null;
                } else if (current == self.tail) {
                    self.tail = current.prev;
                    self.tail.?.next = null;
                } else {
                    const temp = current.prev;
                    current.prev.?.next = current.next;
                    current.next.?.prev = temp;
                }
                return;
            }
            current = current.next orelse return ListErrors.ElementDNE;
        }
    }
    pub fn removeAll(self: *LinkedList, val: u8) ListErrors!void {
        var counter: u8 = 0;
        while (true) {
            self.remove(val) catch break;
            counter += 1;
        }
        return if (counter == 0) ListErrors.ElementDNE;
    }
};

fn printList2(head_: *Node) void {
    var curr = head_;
    while (true) {
        std.debug.print("{}  ", .{curr.value});
        curr = curr.next orelse {
            std.debug.print("\n", .{});
            break;
        };
    }
}

fn printList(head_: *Node) void { // head can't be null or empty
    var head = head_;

    std.debug.print("{}  ", .{head.value});

    while (head.getNext()) |next| {
        std.debug.print("{}  ", .{next.value});
        head = next;
    } else {
        std.debug.print("\n", .{});
    }
}
pub fn main() void {

    // manually linked
    var c = Node{
        .value = 4,
    };
    var b = Node{ .value = 1, .next = &c };
    var a = Node{ .value = 3, .next = &b };

    // linked list struct
    var my_list = LinkedList{ .head = &a, .tail = &a };
    var d = Node{ .value = 133 };
    var e = Node{ .value = 44 };
    var e2 = Node{ .value = 44 };
    var e3 = Node{ .value = 44 };
    var f = Node{ .value = 42 };
    my_list.append(&d);
    my_list.append(&e);
    my_list.append(&e2);
    my_list.append(&e3);
    my_list.append(&f);

    std.debug.print("Print my list:\n", .{});
    my_list.print();
    std.debug.print("Print my list BACKWARDS:\n", .{});
    my_list.printBackwards();

    std.debug.print("\nInline reversing my list...\n", .{});
    my_list.reverse();
    std.debug.print("Print reversed list:\n", .{});
    my_list.print();
    std.debug.print("Print reversed list BACKWARDS (so should be normal):\n", .{});
    my_list.printBackwards();

    std.debug.print("\nPopping the last element...\n", .{});
    const my_node = my_list.pop();
    std.debug.print("This is my popped node: {any}\n", .{my_node});
    std.debug.print("And the list looks like this now:\n", .{});
    my_list.print();
    my_list.printBackwards();

    std.debug.print("\nLet's get rid of 133\n", .{});
    my_list.remove(133) catch std.debug.print("I errored!!\n", .{});
    my_list.print();
    my_list.printBackwards();

    std.debug.print("\nLet's get rid of 100 (it doesn't exist)\n", .{});
    my_list.remove(100) catch std.debug.print("I errored!!\n", .{});
    my_list.print();
    my_list.printBackwards();

    std.debug.print("\nHow many 44's are there?\n", .{});
    std.debug.print("There are {} 44's.\n", .{my_list.count(44)});

    std.debug.print("\nLet's remove all the 44's\n", .{});
    my_list.removeAll(44) catch std.debug.print("womp womp\n", .{});
    my_list.print();
    my_list.printBackwards();

    std.debug.print("Yey Linked Lists :)\n", .{});
}
