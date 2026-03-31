#!/bin/bash

# --- Настройки ---
VIENNA_DIR="./data"         # Папка с JAR
EVENTBUS_PORT=5532            # Порт Event Bus
OBJECTSTORE_PORT=5396        # Порт Object Store
DATA_DIR="$VIENNA_DIR/data"   # Папка с данными для Object Store

# --- Функция запуска JAR в фоне с логом ---
run_jar() {
    local jar_path="$1"
    shift
    echo "Запускаем $jar_path $* ..."
    nohup java -jar "$jar_path" "$@" > "${jar_path%.jar}.log" 2>&1 &
    local pid=$!
    echo "PID $pid для $jar_path"
    echo $pid
}

# --- Функция ожидания порта ---
wait_for_port() {
    local host=$1
    local port=$2
    echo "Ожидание $host:$port..."
    until nc -z "$host" "$port"; do
        sleep 1
    done
    echo "$host:$port доступен!"
}

# --- 1. Event Bus ---
eventbus_server="$VIENNA_DIR/eventbus-server-0.0.1-SNAPSHOT-jar-with-dependencies.jar"
eventbus_pid=$(run_jar "$eventbus_server")
wait_for_port "localhost" $EVENTBUS_PORT

# --- 2. Object Store ---
objectstore_server="$VIENNA_DIR/objectstore-server-0.0.1-SNAPSHOT-jar-with-dependencies.jar"
objectstore_pid=$(run_jar "$objectstore_server" -dataDir "$DATA_DIR" -port $OBJECTSTORE_PORT)
wait_for_port "localhost" $OBJECTSTORE_PORT

# --- 3. Остальные JAR ---
find "$VIENNA_DIR" -maxdepth 1 -type f -name "*.jar" | while read -r jar; do
    if [[ "$jar" != "$eventbus_server" && "$jar" != "$objectstore_server" && "$jar" != "$apiserver" ]]; then
        run_jar "$jar"
    fi
done

# --- 4. API Server ---
java -jar server.jar --db ./earth.db --staticData "$DATA_DIR"

echo "Все JAR файлы Vienna запущены в фоне!"

bash data/stop.sh