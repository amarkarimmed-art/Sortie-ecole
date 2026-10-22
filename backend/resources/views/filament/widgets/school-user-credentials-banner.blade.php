@if (!empty($credentials))
    <div x-data="{ copiedLogin: false, copiedPassword: false }" class="p-6 mb-6 bg-gradient-to-r from-emerald-50 to-teal-100 dark:from-gray-800 dark:to-emerald-950/40 rounded-xl border border-emerald-200 dark:border-emerald-800 shadow-sm">
        <div class="flex items-start justify-between">
            <div class="flex items-center space-x-3">
                <div class="p-2 bg-emerald-600 rounded-lg text-white">
                    <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z"></path>
                    </svg>
                </div>
                <div>
                    <h3 class="text-lg font-bold text-emerald-950 dark:text-white">
                        Identifiants du compte{{ !empty($credentials['school_name']) ? ' — ' . $credentials['school_name'] : '' }}
                    </h3>
                    <p class="text-sm text-emerald-900/80 dark:text-gray-300">
                        ⚠️ <span class="font-semibold text-rose-600 dark:text-rose-400">Notez ces identifiants, ils ne seront plus affichés</span>
                    </p>
                </div>
            </div>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
            <div class="p-3 bg-white dark:bg-gray-900 rounded-lg border border-emerald-100 dark:border-gray-800 flex items-center justify-between">
                <div>
                    <span class="text-xs uppercase font-semibold text-gray-500">Login</span>
                    <p class="text-base font-mono font-bold text-gray-900 dark:text-white select-all">{{ $credentials['login'] }}</p>
                </div>
                <button 
                    type="button"
                    @click="navigator.clipboard.writeText('{{ $credentials['login'] }}'); copiedLogin = true; setTimeout(() => copiedLogin = false, 2500)"
                    class="px-3 py-1.5 text-xs font-semibold text-emerald-700 bg-emerald-50 hover:bg-emerald-100 dark:text-emerald-300 dark:bg-gray-800 rounded-md transition shadow-sm"
                >
                    <span x-show="!copiedLogin">Copier</span>
                    <span x-show="copiedLogin" class="text-emerald-600 font-bold">✓ Copié !</span>
                </button>
            </div>

            <div class="p-3 bg-white dark:bg-gray-900 rounded-lg border border-emerald-100 dark:border-gray-800 flex items-center justify-between">
                <div>
                    <span class="text-xs uppercase font-semibold text-gray-500">Mot de passe en clair</span>
                    <p class="text-base font-mono font-bold text-gray-900 dark:text-white select-all">{{ $credentials['password'] }}</p>
                </div>
                <button 
                    type="button"
                    @click="navigator.clipboard.writeText('{{ $credentials['password'] }}'); copiedPassword = true; setTimeout(() => copiedPassword = false, 2500)"
                    class="px-3 py-1.5 text-xs font-semibold text-emerald-700 bg-emerald-50 hover:bg-emerald-100 dark:text-emerald-300 dark:bg-gray-800 rounded-md transition shadow-sm"
                >
                    <span x-show="!copiedPassword">Copier</span>
                    <span x-show="copiedPassword" class="text-emerald-600 font-bold">✓ Copié !</span>
                </button>
            </div>
        </div>
    </div>
@endif
