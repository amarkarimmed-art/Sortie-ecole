<x-filament-panels::page>
    <div class="space-y-6">

        {{-- Bandeau d'état et boutons d'exception --}}
        <div class="p-5 bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700">
            <div class="flex flex-col md:flex-row md:items-center justify-between gap-4">
                <div>
                    <h3 class="text-base font-semibold text-gray-900 dark:text-gray-100 flex items-center gap-2">
                        <x-heroicon-o-bolt class="w-5 h-5 text-amber-500" />
                        Débrayage Exceptionnel des Horaires
                    </h3>
                    <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
                        Fuseau horaire : Africa/Casablanca (Heure locale Maroc)
                    </p>
                    <div class="mt-2">
                        @if ($overrideState === 'open')
                            <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium bg-emerald-100 text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-300">
                                <span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
                                Sortie ouverte jusqu'à {{ $overrideUntil ?? 'la fin de la session' }}
                            </span>
                        @elseif ($overrideState === 'closed')
                            <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium bg-rose-100 text-rose-800 dark:bg-rose-900/40 dark:text-rose-300">
                                <span class="w-2 h-2 rounded-full bg-rose-500"></span>
                                Sortie fermée manuellement
                            </span>
                        @else
                            <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800 dark:bg-blue-900/40 dark:text-blue-300">
                                <span class="w-2 h-2 rounded-full bg-blue-500"></span>
                                Horaires automatiques actifs
                            </span>
                        @endif
                    </div>
                </div>

                <div class="flex flex-wrap items-center gap-2">
                    <button type="button" wire:click="openNow" class="inline-flex items-center gap-1.5 px-3 py-2 text-xs font-medium text-white bg-emerald-600 hover:bg-emerald-700 rounded-lg shadow-sm transition">
                        <x-heroicon-o-arrow-top-right-on-square class="w-4 h-4" />
                        Ouvrir la sortie maintenant
                    </button>
                    <button type="button" wire:click="closeNow" class="inline-flex items-center gap-1.5 px-3 py-2 text-xs font-medium text-white bg-rose-600 hover:bg-rose-700 rounded-lg shadow-sm transition">
                        <x-heroicon-o-no-symbol class="w-4 h-4" />
                        Fermer la sortie
                    </button>
                    @if ($overrideState !== null)
                        <button type="button" wire:click="resetOverride" class="inline-flex items-center gap-1.5 px-3 py-2 text-xs font-medium text-gray-700 dark:text-gray-200 bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 rounded-lg transition">
                            <x-heroicon-o-arrow-path class="w-4 h-4" />
                            Rétablir l'automatisme
                        </button>
                    @endif
                </div>
            </div>
        </div>

        {{-- Formulaire Filament classique (Nom, Logo, Marges, etc.) --}}
        <x-filament-panels::form wire:submit="save">
            {{ $this->form }}

            {{-- SECTION CARTE INTERACTIVE LEAFLET (Périmètre GPS) --}}
            <div class="p-6 bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 space-y-4"
                 x-data="gpsMapComponent({
                     lat: @entangle('data.gate_latitude'),
                     lng: @entangle('data.gate_longitude'),
                     radius: @entangle('data.perimeter_radius')
                 })"
                 x-init="initMap()">

                <div class="flex flex-col md:flex-row md:items-center justify-between gap-4">
                    <div>
                        <h3 class="text-base font-semibold text-gray-900 dark:text-gray-100 flex items-center gap-2">
                            <x-heroicon-o-map-pin class="w-5 h-5 text-primary-500" />
                            Carte Interactive du Portail et Périmètre GPS
                        </h3>
                        <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
                            Cliquez sur la carte ou déplacez le marqueur pour définir l'emplacement exact du portail.
                        </p>
                    </div>

                    <div class="flex flex-wrap items-center gap-2">
                        <button type="button" @click="locateAdmin()" class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-primary-700 bg-primary-50 dark:bg-primary-950 dark:text-primary-300 hover:bg-primary-100 rounded-lg border border-primary-200 dark:border-primary-800 transition">
                            <x-heroicon-o-map-pin class="w-4 h-4" />
                            Utiliser ma position actuelle
                        </button>
                        <button type="button" @click="testDistance()" class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-gray-700 dark:text-gray-200 bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 rounded-lg transition">
                            <x-heroicon-o-calculator class="w-4 h-4" />
                            Tester ma distance
                        </button>
                    </div>
                </div>

                {{-- Bannière d'avertissement si non configuré --}}
                <div x-show="!lat || !lng" class="p-3 bg-amber-50 dark:bg-amber-950/40 border-l-4 border-amber-500 rounded-r-lg text-xs text-amber-800 dark:text-amber-200 flex items-center gap-2">
                    <x-heroicon-o-exclamation-triangle class="w-5 h-5 shrink-0 text-amber-500" />
                    <span><strong>Attention :</strong> Le portail de l'école n'est pas encore positionné. Cliquez sur la carte pour placer le repère.</span>
                </div>

                {{-- Badge de résultat du test de distance --}}
                <div x-show="testResult !== null" x-cloak class="p-3 rounded-lg text-xs font-medium flex items-center justify-between"
                     :class="inPerimeter ? 'bg-emerald-50 text-emerald-800 dark:bg-emerald-950/40 dark:text-emerald-300 border border-emerald-200' : 'bg-rose-50 text-rose-800 dark:bg-rose-950/40 dark:text-rose-300 border border-rose-200'">
                    <span x-text="testResult"></span>
                    <button type="button" @click="testResult = null" class="text-xs opacity-75 hover:opacity-100">&times;</button>
                </div>

                {{-- Boutons rapides de rayon --}}
                <div class="flex items-center gap-2">
                    <span class="text-xs font-medium text-gray-600 dark:text-gray-300">Rayons rapides :</span>
                    <template x-for="r in [20, 50, 100, 200]" :key="r">
                        <button type="button" @click="setRadius(r)"
                                class="px-2.5 py-1 text-xs rounded-md font-medium border transition"
                                :class="radius == r ? 'bg-primary-600 text-white border-primary-600' : 'bg-gray-50 text-gray-700 dark:bg-gray-700 dark:text-gray-300 border-gray-300 hover:bg-gray-100'">
                            <span x-text="r + ' m'"></span>
                        </button>
                    </template>
                </div>

                {{-- Conteneur de la carte Leaflet --}}
                <div id="school-gate-map" class="w-full h-80 rounded-xl border border-gray-300 dark:border-gray-700 shadow-inner z-0" style="min-height: 320px;"></div>
            </div>

            {{-- SECTION GESTION DES PLAGES HORAIRES (PickupWindows) --}}
            <div class="p-6 bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 space-y-5">
                <div class="flex flex-col md:flex-row md:items-center justify-between gap-4">
                    <div>
                        <h3 class="text-base font-semibold text-gray-900 dark:text-gray-100 flex items-center gap-2">
                            <x-heroicon-o-clock class="w-5 h-5 text-primary-500" />
                            Plages Horaires de Sortie
                            <span class="text-xs px-2 py-0.5 rounded font-normal {{ $is_ramadan_mode ? 'bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300' : 'bg-gray-100 text-gray-700 dark:bg-gray-700 dark:text-gray-300' }}">
                                {{ $is_ramadan_mode ? 'Régime Ramadan' : 'Régime Normal' }}
                            </span>
                        </h3>
                        @php
                            $serverNow = \Carbon\Carbon::now('Africa/Casablanca');
                            $dayNameFr = [1 => 'Lundi', 2 => 'Mardi', 3 => 'Mercredi', 4 => 'Jeudi', 5 => 'Vendredi', 6 => 'Samedi', 7 => 'Dimanche'][$serverNow->dayOfWeekIso];
                            $serverTimeDisplay = $dayNameFr . ' ' . $serverNow->format('H:i');
                            $liveStatus = $this->getLiveScheduleStatus();
                        @endphp
                        <div class="mt-2 flex flex-wrap items-center gap-3">
                            <p class="text-xs text-gray-600 dark:text-gray-300 font-medium">
                                <span class="font-semibold text-gray-800 dark:text-gray-100">Heure actuelle du serveur (Africa/Casablanca) :</span> {{ $serverTimeDisplay }}
                            </p>
                            @if ($liveStatus['is_open'] ?? false)
                                <span class="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-100 text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-300">
                                    <span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
                                    {{ $liveStatus['message_fr'] ?? 'Sortie ouverte' }}
                                </span>
                            @else
                                <span class="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-rose-100 text-rose-800 dark:bg-rose-900/40 dark:text-rose-300">
                                    <span class="w-2 h-2 rounded-full bg-rose-500"></span>
                                    {{ $liveStatus['message_fr'] ?? 'Sortie fermée' }}
                                </span>
                            @endif
                        </div>
                        <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
                            Configurez les heures de sonnerie où le portail est ouvert aux arrivées.
                        </p>
                    </div>

                    <button type="button" wire:click="copyDayToAll({{ $activeDay }})" class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-gray-700 dark:text-gray-200 bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 rounded-lg transition shadow-sm">
                        <x-heroicon-o-document-duplicate class="w-4 h-4 text-primary-600" />
                        Copier ce jour vers tous les jours
                    </button>
                </div>

                {{-- Sélecteur de jour (Lundi -> Dimanche) --}}
                @php
                    $days = [
                        1 => 'Lundi',
                        2 => 'Mardi',
                        3 => 'Mercredi',
                        4 => 'Jeudi',
                        5 => 'Vendredi',
                        6 => 'Samedi',
                        7 => 'Dimanche',
                    ];
                    $todayIso = (int) \Carbon\Carbon::now('Africa/Casablanca')->dayOfWeekIso;
                @endphp

                <div class="flex flex-wrap gap-1.5 border-b border-gray-200 dark:border-gray-700 pb-3">
                    @foreach ($days as $num => $label)
                        @php
                            $countForDay = count(array_filter($windows, fn($w) => (int)$w['day_of_week'] === $num && (bool)$w['is_ramadan'] === $is_ramadan_mode));
                            $isToday = ($num === $todayIso);
                        @endphp
                        <button type="button" wire:click="setActiveDay({{ $num }})"
                                class="px-3 py-1.5 rounded-lg text-xs font-medium transition flex items-center gap-1.5 {{ $activeDay === $num ? 'bg-primary-600 text-white shadow-sm' : 'bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-200' }}">
                            {{ $label }}
                            @if ($isToday)
                                <span class="px-1.5 py-0.5 rounded text-[10px] font-bold {{ $activeDay === $num ? 'bg-emerald-500 text-white ring-1 ring-white/50' : 'bg-emerald-100 text-emerald-800 dark:bg-emerald-900/60 dark:text-emerald-300' }}">
                                    Aujourd'hui
                                </span>
                            @endif
                            @if ($countForDay > 0)
                                <span class="px-1.5 py-0.2 rounded-full text-[10px] {{ $activeDay === $num ? 'bg-primary-800 text-white' : 'bg-gray-300 dark:bg-gray-600 text-gray-800 dark:text-gray-200' }}">
                                    {{ $countForDay }}
                                </span>
                            @endif
                        </button>
                    @endforeach
                </div>

                {{-- Liste des plages pour le jour actif et le régime actif --}}
                <div class="space-y-3">
                    @php
                        $dayWindows = array_filter($windows, fn($w) => (int)$w['day_of_week'] === $activeDay && (bool)$w['is_ramadan'] === $is_ramadan_mode);
                    @endphp

                    @if (empty($dayWindows))
                        <div class="p-4 bg-gray-50 dark:bg-gray-900 rounded-lg text-center text-xs text-gray-500">
                            Aucune plage horaire configurée pour le {{ $days[$activeDay] }} ({{ $is_ramadan_mode ? 'Ramadan' : 'Normal' }}).
                        </div>
                    @else
                        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                            @foreach ($windows as $index => $w)
                                @if ((int)$w['day_of_week'] === $activeDay && (bool)$w['is_ramadan'] === $is_ramadan_mode)
                                    <div class="flex items-center gap-3 p-3 bg-gray-50 dark:bg-gray-900 rounded-lg border border-gray-200 dark:border-gray-700">
                                        <div class="flex-1">
                                            <label class="block text-[11px] font-medium text-gray-500 mb-1">Début (HH:MM)</label>
                                            <input type="time" wire:model.live="windows.{{ $index }}.start_time" class="w-full text-xs rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-800" required>
                                        </div>
                                        <span class="text-gray-400 mt-4">&rarr;</span>
                                        <div class="flex-1">
                                            <label class="block text-[11px] font-medium text-gray-500 mb-1">Fin (HH:MM)</label>
                                            <input type="time" wire:model.live="windows.{{ $index }}.end_time" class="w-full text-xs rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-800" required>
                                        </div>
                                        <div class="mt-4">
                                            <button type="button" wire:click="removeWindow({{ $index }})" class="p-1.5 text-rose-500 hover:text-rose-700 rounded-md hover:bg-rose-50 dark:hover:bg-rose-950/30 transition">
                                                <x-heroicon-o-trash class="w-4 h-4" />
                                            </button>
                                        </div>
                                    </div>
                                @endif
                            @endforeach
                        </div>
                    @endif

                    <div class="pt-2">
                        <button type="button" wire:click="addWindow({{ $activeDay }})" class="inline-flex items-center gap-1.5 px-3 py-2 text-xs font-medium text-primary-700 bg-primary-50 dark:bg-primary-950 dark:text-primary-300 hover:bg-primary-100 rounded-lg transition border border-primary-200 dark:border-primary-800">
                            <x-heroicon-o-plus class="w-4 h-4" />
                            Ajouter une plage horaire le {{ $days[$activeDay] }}
                        </button>
                    </div>
                </div>
            </div>

            {{-- Bouton d'enregistrement général --}}
            <div class="pt-4 flex justify-end">
                <button type="submit" class="px-5 py-2.5 bg-primary-600 hover:bg-primary-700 text-white rounded-lg text-sm font-medium shadow-sm transition flex items-center gap-2">
                    <x-heroicon-o-check class="w-4 h-4" />
                    Enregistrer les paramètres
                </button>
            </div>
        </x-filament-panels::form>
    </div>

    {{-- Script Leaflet et AlpineJS --}}
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="" />
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>

    <script>
        function gpsMapComponent(config) {
            return {
                lat: config.lat,
                lng: config.lng,
                radius: config.radius || 50,
                map: null,
                marker: null,
                circle: null,
                testResult: null,
                inPerimeter: false,

                initMap() {
                    const defaultLat = this.lat ? parseFloat(this.lat) : 33.5731104; // Casablanca
                    const defaultLng = this.lng ? parseFloat(this.lng) : -7.5898434;

                    this.$nextTick(() => {
                        if (this.map) return;

                        this.map = L.map('school-gate-map').setView([defaultLat, defaultLng], this.lat ? 17 : 13);

                        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                            maxZoom: 19,
                            attribution: '© OpenStreetMap'
                        }).addTo(this.map);

                        if (this.lat && this.lng) {
                            this.setMarkerAndCircle(defaultLat, defaultLng, parseInt(this.radius));
                        }

                        this.map.on('click', (e) => {
                            this.updatePosition(e.latlng.lat, e.latlng.lng);
                            $wire.saveGateLocation(e.latlng.lat, e.latlng.lng, false);
                        });

                        // Surveiller les changements de rayon
                        this.$watch('radius', (newR) => {
                            if (this.circle) {
                                this.circle.setRadius(parseInt(newR));
                            }
                        });
                    });
                },

                setMarkerAndCircle(lat, lng, radius) {
                    if (this.marker) {
                        this.marker.setLatLng([lat, lng]);
                    } else {
                        this.marker = L.marker([lat, lng], { draggable: true }).addTo(this.map);
                        this.marker.on('dragend', (e) => {
                            const pos = e.target.getLatLng();
                            this.updatePosition(pos.lat, pos.lng);
                            $wire.saveGateLocation(pos.lat, pos.lng, false);
                        });
                        this.marker.bindPopup("<b>Portail de l'école</b>").openPopup();
                    }

                    if (this.circle) {
                        this.circle.setLatLng([lat, lng]);
                        this.circle.setRadius(radius);
                    } else {
                        this.circle = L.circle([lat, lng], {
                            radius: radius,
                            color: '#10b981',
                            fillColor: '#10b981',
                            fillOpacity: 0.2
                        }).addTo(this.map);
                    }
                },

                updatePosition(lat, lng) {
                    this.lat = lat.toFixed(7);
                    this.lng = lng.toFixed(7);
                    this.setMarkerAndCircle(lat, lng, parseInt(this.radius));
                },

                setRadius(r) {
                    this.radius = r;
                    if (this.circle) {
                        this.circle.setRadius(r);
                    }
                    $wire.saveRadius(r);
                },

                locateAdmin() {
                    if (!navigator.geolocation) {
                        alert("La géolocalisation n'est pas supportée par votre navigateur.");
                        return;
                    }
                    navigator.geolocation.getCurrentPosition((pos) => {
                        const lat = pos.coords['lat' + 'itude'];
                        const lng = pos.coords['long' + 'itude'];
                        this.updatePosition(lat, lng);
                        this.map.setView([lat, lng], 17);
                        $wire.saveGateLocation(lat, lng, true);
                    }, (err) => {
                        alert("Impossible de récupérer votre position : " + err.message);
                    }, { enableHighAccuracy: true });
                },

                testDistance() {
                    if (!this.lat || !this.lng) {
                        alert("Veuillez d'abord positionner le portail sur la carte.");
                        return;
                    }
                    if (!navigator.geolocation) {
                        alert("La géolocalisation n'est pas supportée par votre navigateur.");
                        return;
                    }

                    navigator.geolocation.getCurrentPosition((pos) => {
                        const adminLat = pos.coords['lat' + 'itude'];
                        const adminLng = pos.coords['long' + 'itude'];
                        const gateLat = parseFloat(this.lat);
                        const gateLng = parseFloat(this.lng);

                        const dist = this.haversineDistance(adminLat, adminLng, gateLat, gateLng);
                        const r = parseInt(this.radius);
                        this.inPerimeter = (dist <= r);

                        if (this.inPerimeter) {
                            this.testResult = `Vous êtes à ${dist} m du portail — Dans le périmètre (${r} m)`;
                        } else {
                            this.testResult = `Vous êtes à ${dist} m du portail — Hors périmètre (limite : ${r} m)`;
                        }
                    }, (err) => {
                        alert("Erreur de géolocalisation : " + err.message);
                    }, { enableHighAccuracy: true });
                },

                haversineDistance(lat1, lon1, lat2, lon2) {
                    const R = 6371000;
                    const dLat = (lat2 - lat1) * Math.PI / 180;
                    const dLon = (lon2 - lon1) * Math.PI / 180;
                    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                              Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
                              Math.sin(dLon / 2) * Math.sin(dLon / 2);
                    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
                    return Math.round(R * c);
                }
            };
        }
    </script>
</x-filament-panels::page>
