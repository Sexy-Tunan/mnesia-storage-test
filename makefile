PROJECT = mnesia_test
REBAR = rebar3
EBIN = _build/default/lib/$(PROJECT)/ebin

# 默认目标
all: compile

# 清理 + 编译
compile:
	@$(REBAR) clean
	@$(REBAR) compile

# 启动 erl shell 并自动加载依赖与应用
run:
	@$(REBAR) compile
	@erl -pa _build/default/lib/*/ebin -eval " application:ensure_all_started($(PROJECT))."

# 只启动 shell，不启动 app
shell:
	@$(REBAR) compile
	@erl -pa _build/default/lib/*/ebin

# 一键重启（清理 + 编译 + 启动）
restart: clean-db
	@$(REBAR) clean
	@$(REBAR) compile
	@erl -sname tester -pa _build/default/lib/*/ebin -eval "application:ensure_all_started($(PROJECT)), application:start($(PROJECT))"

test_disc_copies: clean-db
	@$(REBAR) clean
	@$(REBAR) compile
	@erl -sname tester -pa _build/default/lib/*/ebin -eval "application:ensure_all_started($(PROJECT)), application:start($(PROJECT)), tester:test_disc_copies()"

test_disc_only_copies: clean-db
	@$(REBAR) clean
	@$(REBAR) compile
	@erl -sname tester -pa _build/default/lib/*/ebin -eval "application:ensure_all_started($(PROJECT)), application:start($(PROJECT)), tester:test_disc_only_copies()"

# 清理
clean:
	@echo "使用rebar3清理beam文件"
	@$(REBAR) clean

# 清理 mnesia 数据库文件
clean-db:
	@echo "清理 Mnesia 数据库文件..."
	@rm -rf Mnesia.*
	@echo "数据库文件已清理"

clean-all: clean clean-db
