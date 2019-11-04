require 'autoproj/test'

module Autoproj
    module PackageManagers
        describe BundlerManager do
            describe ".run_bundler" do
                it "defaults to the workspace's shim if program['bundler'] is not initialized" do
                    Autobuild.programs['bundle'] = nil
                    ws = flexmock(dot_autoproj_dir: '/some/path')
                    ws.should_receive(:run)
                      .with(any, any, '/some/path/bin/bundle', 'some', 'program', Hash, Proc)
                      .once
                    BundlerManager.run_bundler(ws, 'some', 'program',
                                               gem_home: '/gem/home',
                                               gemfile: '/gem/path/Gemfile')
                end
            end

            describe ".apply_build_config" do
                before do
                    @ws = ws_create
                    @bundler_manager = BundlerManager.new(@ws)
                    @bundler_manager.initialize_environment
                end

                def run_bundler_config
                    `BUNDLE_GEMFILE=#{@ws.prefix_dir}/gems/Gemfile bundle config`.split("\n")
                end

                it "adds build configurations" do
                    BundlerManager.configure_build_for('testgem', '--some=config', ws: @ws)
                    BundlerManager.apply_build_config(@ws)

                    lines = run_bundler_config.each_cons(2).find do |a, b|
                        a =~ /build.testgem/
                    end
                    assert_match(/Set for your local app.*: "--some=config"/,
                                 lines[1])
                end
                it "updates existing build configurations" do
                    BundlerManager.configure_build_for('testgem', '--some=config', ws: @ws)
                    BundlerManager.apply_build_config(@ws)
                    BundlerManager.configure_build_for('testgem', '--some=other', ws: @ws)
                    BundlerManager.apply_build_config(@ws)

                    lines = run_bundler_config.each_cons(2).find do |a, b|
                        a =~ /build.testgem/
                    end
                    assert_match(/Set for your local app.*: "--some=other"/,
                                 lines[1])
                end
                it "removes obsolete build configurations" do
                    BundlerManager.configure_build_for('testgem', '--some=config', ws: @ws)
                    BundlerManager.apply_build_config(@ws)
                    BundlerManager.remove_build_configuration_for('testgem', ws: @ws)
                    BundlerManager.apply_build_config(@ws)

                    lines = run_bundler_config.each_cons(2).find do |a, b|
                        a =~ /build.testgem/
                    end
                    refute lines
                end
                it "appends to existing build configuration with add_build_configuration_for" do
                    BundlerManager.configure_build_for('testgem', '--some=config', ws: @ws)
                    BundlerManager.apply_build_config(@ws)
                    BundlerManager.add_build_configuration_for('testgem', '--some=other', ws: @ws)
                    BundlerManager.apply_build_config(@ws)

                    lines = run_bundler_config.each_cons(2).find do |a, b|
                        a =~ /build.testgem/
                    end
                    assert_match(/Set for your local app.*: "--some=config --some=other"/,
                                 lines[1])
                end
            end

            describe "#initialize_environment" do
                before do
                    @ws = ws_create
                    @bundler_manager = BundlerManager.new(@ws)
                    @cache_dir = make_tmpdir
                    @vendor_cache_path =
                        File.join(@ws.prefix_dir, 'gems', 'vendor', 'cache')
                end

                describe "cache setup" do
                    it 'symlinks the cache dir to vendor/cache if cache_dir is set' do
                        @bundler_manager.cache_dir = @cache_dir
                        @bundler_manager.initialize_environment

                        assert_equal @cache_dir, File.readlink(@vendor_cache_path)
                    end

                    it 'updates an existing symlink to the current cache' do
                        @bundler_manager.cache_dir = @cache_dir
                        FileUtils.mkdir_p File.dirname(@vendor_cache_path)
                        FileUtils.ln_s '/some/path', @vendor_cache_path
                        @bundler_manager.initialize_environment

                        assert_equal @cache_dir, File.readlink(@vendor_cache_path)
                    end

                    it 'skips an existing directory' do
                        @bundler_manager.cache_dir = @cache_dir
                        FileUtils.mkdir_p @vendor_cache_path
                        flexmock(Autoproj).should_receive(:warn).once
                                          .with(/cannot use #{@cache_dir}/)
                        @bundler_manager.initialize_environment

                        assert File.directory?(@vendor_cache_path)
                    end
                end
            end
        end
    end
end
