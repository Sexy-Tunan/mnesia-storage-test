测试Mnesia的最大存储，其中
Mnesia 采用 disc_copies 模式
对比
Mnesia 采用 disc_only_copies 模式

{disc_copies, Nodelist},其中 Nodelist 是一个列表，它列出了应该具有 disc_copies 的节点。
如果一个表副本的类型是 disc_copies，那么对该表特定副本的所有写操作都会写入 disc，并写入表的 RAM 副本(创建表的节点会有一个RAM内存副本，并不是所有节点都有)。
可以在一个节点上有一个 disc_copies 类型的复制表，而在另一个节点上有另一种类型的复制表。默认值是[]


{disc_only_copies, Nodelist},其中 Nodelist 是一个列表，列出了该表应该具有 disc_only_copies 的节点。
一个disc_only 表副本只保留在 disc 上，与其它副本类型不同，副本的内容不驻留在 RAM 中。
这些副本比驻留在RAM中的副本慢得多。