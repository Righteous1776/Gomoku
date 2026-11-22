cmake_minimum_required(VERSION 3.20)
project(ECLIPSE VERSION 0.1.0 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
add_library(eclipse_core STATIC src/board.cpp src/search.cpp src/eclipse_c_api.cpp)
target_include_directories(eclipse_core PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
if(MSVC)
  target_compile_options(eclipse_core PRIVATE /W4)
else()
  target_compile_options(eclipse_core PRIVATE -Wall -Wextra -Wpedantic)
endif()
add_executable(gomoku_cli src/gomoku_cli.cpp)
target_link_libraries(gomoku_cli PRIVATE eclipse_core)
include(CTest)
if(BUILD_TESTING)
  add_executable(eclipse_rules_tests tests/test_rules.cpp)
  target_link_libraries(eclipse_rules_tests PRIVATE eclipse_core)
  add_test(NAME eclipse_rules COMMAND eclipse_rules_tests)
  add_executable(eclipse_rules_parity_tests tests/test_rules_parity.cpp)
  target_link_libraries(eclipse_rules_parity_tests PRIVATE eclipse_core)
  add_test(NAME eclipse_rules_parity COMMAND eclipse_rules_parity_tests)
  find_package(Threads REQUIRED)
  add_executable(eclipse_compute_policy_v2_tests tests/test_compute_policy_v2.cpp)
  target_link_libraries(eclipse_compute_policy_v2_tests PRIVATE eclipse_core Threads::Threads)
  add_test(NAME eclipse_compute_policy_v2 COMMAND eclipse_compute_policy_v2_tests)
  set_tests_properties(eclipse_compute_policy_v2 PROPERTIES TIMEOUT 30)
  add_executable(eclipse_live_search_snapshot_v1_tests tests/test_live_search_snapshot_v1.cpp)
  target_link_libraries(eclipse_live_search_snapshot_v1_tests PRIVATE eclipse_core Threads::Threads)
  add_test(NAME eclipse_live_search_snapshot_v1 COMMAND eclipse_live_search_snapshot_v1_tests)
  set_tests_properties(eclipse_live_search_snapshot_v1 PROPERTIES TIMEOUT 30)
  # Adaptive V3 is opt-in; enforce its stop decisions without weakening
  # historical V2 trainer-policy/Swift parity semantics.
  add_executable(eclipse_adaptive_stop_v3_tests tests/test_adaptive_stop_v3.cpp)
  target_link_libraries(eclipse_adaptive_stop_v3_tests PRIVATE eclipse_core Threads::Threads)
  add_test(NAME eclipse_adaptive_stop_v3 COMMAND eclipse_adaptive_stop_v3_tests)
  set_tests_properties(eclipse_adaptive_stop_v3 PROPERTIES TIMEOUT 30)
  # V9 synthetic mandatory-defense regression, exercised through the real R19
  # C ABI V2 search path, independent of any staged LightGBM checkpoint.
  # Compile the actual staged Astra V9 (314) and Sol V9 (160) forests
  # against the production 26D feature extractor; never claim they are loaded.
  add_executable(eclipse_v9_forest_research_tests tests/test_v9_forest_research.cpp)
  target_include_directories(eclipse_v9_forest_research_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
  add_test(NAME eclipse_v9_forest_research COMMAND eclipse_v9_forest_research_tests)
  # R21: actual opt-in V9 V2 ABI execution test, not an active model binding.
  # Optional portable Python CLI smoke: only synthetic boards, no private data.
  find_package(Python3 QUIET COMPONENTS Interpreter)
  if(Python3_Interpreter_FOUND)
    add_test(NAME eclipse_v9_compiled_forest_provenance
      COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_CURRENT_SOURCE_DIR}/tools/verify_v9_compiled_provenance.py)
    add_test(NAME eclipse_v9_cli_rankers
      COMMAND ${Python3_EXECUTABLE}
        ${CMAKE_CURRENT_SOURCE_DIR}/tests/test_v9_cli_rankers.py
        $<TARGET_FILE:gomoku_cli>)
  endif()
  add_executable(eclipse_v9_search_runtime_tests tests/test_v9_search_runtime.cpp)
  target_link_libraries(eclipse_v9_search_runtime_tests PRIVATE eclipse_core)
  target_include_directories(eclipse_v9_search_runtime_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
  add_test(NAME eclipse_v9_search_runtime COMMAND eclipse_v9_search_runtime_tests)
  # R22 headless TRUE game arena: explicit real Astra/Sol/R10 selected at each ply.
  # Full paired matches run in a standalone CI job, never in the main fast CTest.
  add_executable(eclipse_v9_arena tests/arena_v9_rankers.cpp)
  target_link_libraries(eclipse_v9_arena PRIVATE eclipse_core)
  add_executable(eclipse_r07_native_playable_tests tests/test_r07_native_playable.cpp)
  target_include_directories(eclipse_r07_native_playable_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
  target_link_libraries(eclipse_r07_native_playable_tests PRIVATE eclipse_core)
  add_test(NAME eclipse_r07_native_playable
    COMMAND eclipse_r07_native_playable_tests
      ${CMAKE_SOURCE_DIR}/Training/research/r07/checkpoints/eclipse_r07_34d_249_trees.txt)
  set_tests_properties(eclipse_r07_native_playable PROPERTIES TIMEOUT 30)
  # R26: SHA-verified R25 teacher-distilled 273-tree forest inside the same
  # actual native PVS + forced-line search (research only).
  add_executable(eclipse_r25_zenith_search_tests tests/test_r25_zenith_search.cpp)
  target_include_directories(eclipse_r25_zenith_search_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
  target_link_libraries(eclipse_r25_zenith_search_tests PRIVATE eclipse_core)
  add_test(NAME eclipse_r25_zenith_search
    COMMAND eclipse_r25_zenith_search_tests
      ${CMAKE_SOURCE_DIR}/Training/research/r07/checkpoints/eclipse_r07_34d_249_trees.txt
      ${CMAKE_SOURCE_DIR}/Training/research/r07/candidates/zenith_r25/eclipse_r07_zenith_teacher_273_trees.txt)
  set_tests_properties(eclipse_r25_zenith_search PROPERTIES TIMEOUT 35)
  add_executable(eclipse_r25_vs_r07_arena tests/arena_r25_vs_r07.cpp)
  target_include_directories(eclipse_r25_vs_r07_arena PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
  target_link_libraries(eclipse_r25_vs_r07_arena PRIVATE eclipse_core)
  # Do not put long full-game matches into the fast CTest: a dedicated Actions
  # workflow replays all moves and checks W/L/D independently.
  add_executable(eclipse_v9_compiled_binding_tests
    tests/test_v9_compiled_binding.cpp)
  target_link_libraries(eclipse_v9_compiled_binding_tests PRIVATE eclipse_core)
  add_test(NAME eclipse_v9_compiled_binding
    COMMAND eclipse_v9_compiled_binding_tests)
  add_executable(eclipse_v9_unique_block_tests tests/test_v9_unique_block.cpp)
  target_link_libraries(eclipse_v9_unique_block_tests PRIVATE eclipse_core)
  add_test(NAME eclipse_v9_unique_block COMMAND eclipse_v9_unique_block_tests)
  add_executable(eclipse_r10_ordering_tests tests/test_trained_ordering.cpp)
  target_include_directories(eclipse_r10_ordering_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
  add_test(NAME eclipse_r10_ordering COMMAND eclipse_r10_ordering_tests)
endif()
