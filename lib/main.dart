
package com.oukutel.otakumemory

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.provider.MediaStore
import android.view.Gravity
import android.view.View
import android.widget.*
import android.text.Editable
import android.text.TextWatcher
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.UUID
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

private const val PREFS = "otaku_memory"
private const val DATA_KEY = "anime_data"

private val BG = Color.rgb(10, 13, 25)
private val PANEL = Color.rgb(23, 29, 47)
private val PANEL2 = Color.rgb(33, 41, 62)
private val RED = Color.rgb(220, 48, 72)
private val WHITE = Color.rgb(245, 247, 255)
private val MUTED = Color.rgb(160, 170, 190)
private val BLUE = Color.rgb(65, 115, 205)

data class AnimeSeason(
    var id: String = UUID.randomUUID().toString(),
    var name: String = "",
    var episodes: String = "",
    var watched: String = "",
    var image: String = ""
)

data class Anime(
    var id: String = UUID.randomUUID().toString(),
    var name: String = "",
    var englishName: String = "",
    var character: String = "",
    var rating: String = "",
    var genres: String = "",
    var status: String = "لم أشاهده بعد",
    var description: String = "",
    var story: String = "",
    var year: String = "",
    var studio: String = "",
    var notes: String = "",
    var image: String = "",
    var favorite: Boolean = false,
    var seasons: MutableList<AnimeSeason> = mutableListOf()
)

class MainActivity : Activity() {

    private val animeList = mutableListOf<Anime>()

    private lateinit var root: LinearLayout
    private lateinit var content: LinearLayout

    private var currentPage = "home"
    private var searchText = ""
    private var draftImage = ""
    private var seasonDraftImage = ""
    private var nickname = ""
    private var profileImage = ""

    private var currentSearchField: EditText? = null

    private val PICK_ANIME_IMAGE = 101
    private val PICK_SEASON_IMAGE = 102
    private val PICK_PROFILE_IMAGE = 103
    private val EXPORT_BACKUP = 104
    private val IMPORT_BACKUP = 105

    private var galleryTarget = PICK_ANIME_IMAGE

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        loadData()
        loadProfile()
        buildApp()
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    private fun makeBg(color: Int, radius: Int = 15): GradientDrawable {
        return GradientDrawable().apply {
            setColor(color)
            cornerRadius = dp(radius).toFloat()
        }
    }

    private fun text(
        value: String,
        size: Float = 14f,
        color: Int = WHITE,
        bold: Boolean = false
    ): TextView {
        return TextView(this).apply {
            text = value
            textSize = size
            setTextColor(color)
            gravity = Gravity.CENTER_VERTICAL
            if (bold) setTypeface(null, Typeface.BOLD)
            setPadding(dp(3), dp(4), dp(3), dp(4))
        }
    }

    private fun makeButton(
        value: String,
        action: () -> Unit,
        color: Int = RED
    ): TextView {
        return TextView(this).apply {
            text = value
            textSize = 14f
            setTextColor(WHITE)
            gravity = Gravity.CENTER
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dp(13), dp(12), dp(13), dp(12))
            background = makeBg(color, 12)
            setOnClickListener { action() }
        }
    }

    private fun makeInput(
        hintText: String,
        value: String = "",
        multiline: Boolean = false
    ): EditText {
        return EditText(this).apply {
            hint = hintText
            setText(value)
            textSize = 14f
            setTextColor(WHITE)
            setHintTextColor(MUTED)
            setPadding(dp(12), dp(10), dp(12), dp(10))
            background = makeBg(PANEL2, 11)
            if (multiline) {
                minLines = 3
                gravity = Gravity.TOP
            } else {
                singleLine = true
            }
        }
    }

    private fun gap(height: Int = 10): View {
        return View(this).apply {
            layoutParams = LinearLayout.LayoutParams(1, dp(height))
        }
    }

    private fun makeCard(): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(13), dp(12), dp(13), dp(12))
            background = makeBg(PANEL, 16)
        }
    }

    private fun buildApp() {
        root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(BG)
        }

        val header = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(15), dp(18), dp(8))
        }

        header.addView(text("ذاكرة الأوتاكو", 23f, WHITE, true))
        header.addView(text("مساحتك الخاصة لعالم الأنمي", 12f, MUTED))
        root.addView(header)

        val scroll = ScrollView(this)
        content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(15), dp(8), dp(15), dp(20))
        }

        scroll.addView(content)
        root.addView(
            scroll,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f
            )
        )

        val nav = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(dp(5), dp(7), dp(5), dp(7))
            setBackgroundColor(PANEL)
        }

        val pages = listOf(
            "الرئيسية" to "home",
            "المكتبة" to "library",
            "الإعدادات" to "settings"
        )

        pages.forEach { item ->
            val tab = TextView(this).apply {
                text = item.first
                textSize = 13f
                gravity = Gravity.CENTER
                setTextColor(if (currentPage == item.second) RED else MUTED)
                setPadding(dp(8), dp(12), dp(8), dp(12))
                setOnClickListener {
                    currentPage = item.second
                    renderPage()
                }
            }
            nav.addView(tab, LinearLayout.LayoutParams(0, dp(48), 1f))
        }

        root.addView(nav)
        setContentView(root)
        renderPage()
    }

    private fun renderPage() {
        content.removeAllViews()
        when (currentPage) {
            "home" -> showHome()
            "library" -> showLibrary()
            "settings" -> showSettings()
        }
    }

    private fun heading(value: String) {
        content.addView(text(value, 18f, WHITE, true))
        content.addView(gap(9))
    }

    private fun showHome() {
        heading("مرحباً بك في عالمك")

        val stats = makeCard()
        stats.addView(text("إحصائيات مكتبتك", 15f, WHITE, true))
        stats.addView(gap(7))
        stats.addView(text("إجمالي الأنميات: ${animeList.size}", 14f, MUTED))
        stats.addView(
            text("المفضلة: ${animeList.count { it.favorite }}", 14f, MUTED)
        )
        stats.addView(
            text("المكتملة: ${animeList.count { it.status == "مكتمل" }}", 14f, MUTED)
        )
        stats.addView(
            text("قيد المشاهدة: ${animeList.count { it.status == "أشاهده حالياً" }}", 14f, MUTED)
        )
        content.addView(stats)

        content.addView(gap(13))
        content.addView(
            makeButton("＋ إضافة أنمي جديد", { showAnimeForm(null) })
        )

        content.addView(gap(18))
        heading("أضيفت مؤخراً")

        if (animeList.isEmpty()) {
            emptyMessage("مكتبتك فارغة. أضف أول أنمي لك.")
        } else {
            animeList.takeLast(5).asReversed().forEach {
                addAnimeCard(it)
            }
        }

        content.addView(gap(12))
        heading("المفضلة")

        val favorites = animeList.filter { it.favorite }
        if (favorites.isEmpty()) {
            emptyMessage("لا توجد أنميات في المفضلة حتى الآن.")
        } else {
            favorites.forEach { addAnimeCard(it) }
        }
    }

    private fun showLibrary() {
        heading("مكتبة الأنمي")

        content.addView(
            makeButton("＋ إضافة أنمي", { showAnimeForm(null) })
        )
        content.addView(gap(12))

        val searchRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val search = makeInput("اكتب اسم الأنمي أو التصنيف...")
        search.setText(searchText)
        currentSearchField = search

        searchRow.addView(
            search,
            LinearLayout.LayoutParams(0, dp(49), 1f)
        )

        val searchButton = makeButton("بحث", {
            searchText = search.text.toString().trim()
            showLibraryResults()
        })

        val buttonParams = LinearLayout.LayoutParams(
            dp(75),
            dp(49)
        )
        buttonParams.marginStart = dp(7)
        searchRow.addView(searchButton, buttonParams)

        content.addView(searchRow)
        content.addView(gap(9))

        search.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(
                s: CharSequence?, start: Int, count: Int, after: Int
            ) {}

            override fun onTextChanged(
                s: CharSequence?, start: Int, before: Int, count: Int
            ) {
                searchText = s.toString()
            }

            override fun afterTextChanged(s: Editable?) {}
        })

        content.addView(
            makeButton("عرض الكل", {
                searchText = ""
                search.setText("")
                showLibraryResults()
            }, BLUE)
        )

        content.addView(gap(12))

        val results = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            tag = "library_results"
        }
        content.addView(results)
        fillLibraryResults(results)
    }

    private fun showLibraryResults() {
        val results = content.findViewWithTag<LinearLayout>("library_results")
            ?: return
        fillLibraryResults(results)
    }

    private fun fillLibraryResults(results: LinearLayout) {
        results.removeAllViews()

        val query = searchText.trim()

        val filtered = animeList.filter { anime ->
            query.isBlank() ||
                anime.name.contains(query, true) ||
                anime.englishName.contains(query, true) ||
                anime.genres.contains(query, true) ||
                anime.character.contains(query, true)
        }

        results.addView(
            text("النتائج: ${filtered.size}", 13f, MUTED, true)
        )
        results.addView(gap(8))

        if (filtered.isEmpty()) {
            results.addView(text("لا توجد نتائج مطابقة.", 14f, MUTED))
            return
        }

        filtered.forEach { anime ->
            results.addView(animeCardView(anime))
            results.addView(gap(9))
        }
    }

    private fun emptyMessage(value: String) {
        val box = makeCard()
        box.addView(text(value, 14f, MUTED))
        content.addView(box)
    }

    private fun addAnimeCard(anime: Anime) {
        content.addView(animeCardView(anime))
        content.addView(gap(9))
    }

    private fun animeCardView(anime: Anime): LinearLayout {
        val box = makeCard()
        box.orientation = LinearLayout.HORIZONTAL
        box.gravity = Gravity.CENTER_VERTICAL

        val image = ImageView(this).apply {
            scaleType = ImageView.ScaleType.CENTER_CROP
            background = makeBg(PANEL2, 10)
        }

        val bitmap = if (anime.image.isNotBlank()) {
            BitmapFactory.decodeFile(anime.image)
        } else null

        if (bitmap != null) image.setImageBitmap(bitmap)

        box.addView(image, LinearLayout.LayoutParams(dp(78), dp(94)))

        val info = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(11), 0, 0, 0)
        }

        info.addView(text(anime.name, 15f, WHITE, true))

        if (anime.englishName.isNotBlank()) {
            info.addView(text(anime.englishName, 12f, MUTED))
        }

        info.addView(
            text("التقييم: ${anime.rating.ifBlank { "—" }}", 12f, MUTED)
        )
        info.addView(text("الحالة: ${anime.status}", 12f, MUTED))
        info.addView(
            text(
                if (anime.favorite) "★ في المفضلة" else "☆",
                12f,
                if (anime.favorite) RED else MUTED
            )
        )

        box.addView(info, LinearLayout.LayoutParams(0, -2, 1f))
        box.setOnClickListener { showDetails(anime.id) }

        return box
    }

    private fun showDetails(id: String) {
        val anime = animeList.find { it.id == id } ?: return

        val details = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(15), dp(12), dp(15), dp(12))
        }

        if (anime.image.isNotBlank()) {
            val image = ImageView(this).apply {
                scaleType = ImageView.ScaleType.CENTER_CROP
                background = makeBg(PANEL2)
                val bitmap = BitmapFactory.decodeFile(anime.image)
                if (bitmap != null) setImageBitmap(bitmap)
            }
            details.addView(
                image,
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    dp(175)
                )
            )
            details.addView(gap(10))
        }

        details.addView(text(anime.name, 21f, WHITE, true))
        details.addView(text("الاسم الإنجليزي: ${anime.englishName.ifBlank { "—" }}"))
        details.addView(text("الشخصية المفضلة: ${anime.character.ifBlank { "—" }}"))
        details.addView(text("التقييم: ${anime.rating.ifBlank { "—" }}"))
        details.addView(text("التصنيفات: ${anime.genres.ifBlank { "—" }}"))
        details.addView(text("الحالة: ${anime.status}"))
        details.addView(text("سنة الإصدار: ${anime.year.ifBlank { "—" }}"))
        details.addView(text("الاستوديو: ${anime.studio.ifBlank { "—" }}"))

        if (anime.description.isNotBlank()) {
            details.addView(gap(8))
            details.addView(text("الوصف", 15f, RED, true))
            details.addView(text(anime.description))
        }

        if (anime.story.isNotBlank()) {
            details.addView(gap(8))
            details.addView(text("القصة", 15f, RED, true))
            details.addView(text(anime.story))
        }

        if (anime.notes.isNotBlank()) {
            details.addView(gap(8))
            details.addView(text("ملاحظاتي", 15f, RED, true))
            details.addView(text(anime.notes))
        }

        details.addView(gap(12))
        details.addView(text("المواسم", 17f, WHITE, true))

        if (anime.seasons.isEmpty()) {
            details.addView(text("لا توجد مواسم مضافة.", 13f, MUTED))
        } else {
            anime.seasons.forEach { season ->
                details.addView(
                    text(
                        "${season.name} | الحلقات: ${season.episodes.ifBlank { "—" }} | شاهدت: ${season.watched.ifBlank { "—" }}",
                        13f,
                        MUTED
                    )
                )
            }
        }

        val scroll = ScrollView(this)
        scroll.addView(details)

        val dialog = AlertDialog.Builder(this)
            .setView(scroll)
            .setPositiveButton("إغلاق", null)
            .setNeutralButton("تعديل", null)
            .setNegativeButton("المواسم", null)
            .create()

        dialog.setOnShowListener {
            dialog.getButton(AlertDialog.BUTTON_NEUTRAL).setOnClickListener {
                dialog.dismiss()
                showAnimeForm(anime)
            }
            dialog.getButton(AlertDialog.BUTTON_NEGATIVE).setOnClickListener {
                dialog.dismiss()
                showSeasonMenu(anime)
            }
        }

        dialog.show()

        // أزرار إضافية لإدارة الأنمي
        dialog.setOnCancelListener {}
    }

    private fun showAnimeForm(anime: Anime?) {
        draftImage = anime?.image ?: ""

        val form = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(14), dp(10), dp(14), dp(10))
        }

        fun field(
            hint: String,
            value: String = "",
            multiline: Boolean = false
        ): EditText {
            val edit = makeInput(hint, value, multiline)
            form.addView(edit)
            form.addView(gap(8))
            return edit
        }

        val name = field("اسم الأنمي *", anime?.name ?: "")
        val english = field("الاسم الإنجليزي", anime?.englishName ?: "")
        val character = field("الشخصية المفضلة", anime?.character ?: "")
        val rating = field("التقييم من 10", anime?.rating ?: "")
        val genres = field("التصنيفات، افصل بينها بفاصلة", anime?.genres ?: "")
        val year = field("سنة الإصدار", anime?.year ?: "")
        val studio = field("الاستوديو", anime?.studio ?: "")
        val description = field("وصف مختصر", anime?.description ?: "", true)
        val story = field("القصة", anime?.story ?: "", true)
        val notes = field("ملاحظاتي", anime?.notes ?: "", true)

        val statuses = arrayOf(
            "لم أشاهده بعد",
            "أشاهده حالياً",
            "مكتمل",
            "متوقف",
            "سأكمله لاحقاً"
        )

        form.addView(text("حالة المشاهدة", 13f, MUTED))

        val status = Spinner(this)
        status.adapter = ArrayAdapter(
            this,
            android.R.layout.simple_spinner_dropdown_item,
            statuses
        )
        val index = statuses.indexOf(anime?.status)
        if (index >= 0) status.setSelection(index)
        form.addView(status)
        form.addView(gap(9))

        form.addView(
            makeButton("اختيار صورة الغلاف من المعرض", {
                galleryTarget = PICK_ANIME_IMAGE
                openGallery()
            }, BLUE)
        )

        val favorite = CheckBox(this).apply {
            text = "إضافة إلى المفضلة"
            setTextColor(WHITE)
            isChecked = anime?.favorite ?: false
        }
        form.addView(favorite)

        val scroll = ScrollView(this)
        scroll.addView(form)

        val dialog = AlertDialog.Builder(this)
            .setTitle(if (anime == null) "إضافة أنمي" else "تعديل الأنمي")
            .setView(scroll)
            .setNegativeButton("إلغاء", null)
            .setPositiveButton("حفظ", null)
            .create()

        dialog.setOnShowListener {
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener {
                val animeName = name.text.toString().trim()

                if (animeName.isBlank()) {
                    name.error = "اسم الأنمي مطلوب"
                    return@setOnClickListener
                }

                val target = anime ?: Anime()

                target.name = animeName
                target.englishName = english.text.toString().trim()
                target.character = character.text.toString().trim()
                target.rating = rating.text.toString().trim()
                target.genres = genres.text.toString().trim()
                target.year = year.text.toString().trim()
                target.studio = studio.text.toString().trim()
                target.description = description.text.toString().trim()
                target.story = story.text.toString().trim()
                target.notes = notes.text.toString().trim()
                target.status = status.selectedItem.toString()
                target.favorite = favorite.isChecked
                target.image = draftImage

                if (anime == null) {
                    animeList.add(target)
                }

                saveData()
                dialog.dismiss()
                renderPage()
                toast("تم حفظ الأنمي")
            }
        }

        dialog.show()
    }

    private fun showSeasonMenu(anime: Anime) {
        val options = arrayOf(
            "إضافة موسم",
            "عرض المواسم",
            "حذف موسم"
        )

        AlertDialog.Builder(this)
            .setTitle("مواسم ${anime.name}")
            .setItems(options) { _, which ->
                when (which) {
                    0 -> showSeasonForm(anime)
                    1 -> showSeasonList(anime)
                    2 -> deleteSeason(anime)
                }
            }
            .setNegativeButton("إغلاق", null)
            .show()
    }

    private fun showSeasonForm(anime: Anime) {
        seasonDraftImage = ""

        val form = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(14), dp(10), dp(14), dp(10))
        }

        val name = makeInput("اسم الموسم")
        val episodes = makeInput("عدد الحلقات")
        val watched = makeInput("عدد الحلقات التي شاهدتها")

        form.addView(name)
        form.addView(gap(8))
        form.addView(episodes)
        form.addView(gap(8))
        form.addView(watched)
        form.addView(gap(8))

        form.addView(
            makeButton("اختيار صورة الموسم من المعرض", {
                galleryTarget = PICK_SEASON_IMAGE
                openGallery()
            }, BLUE)
        )

        val dialog = AlertDialog.Builder(this)
            .setTitle("إضافة موسم")
            .setView(form)
            .setNegativeButton("إلغاء", null)
            .setPositiveButton("حفظ", null)
            .create()

        dialog.setOnShowListener {
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener {
                if (name.text.toString().trim().isBlank()) {
                    name.error = "اكتب اسم الموسم"
                    return@setOnClickListener
                }

                anime.seasons.add(
                    AnimeSeason(
                        name = name.text.toString().trim(),
                        episodes = episodes.text.toString().trim(),
                        watched = watched.text.toString().trim(),
                        image = seasonDraftImage
                    )
                )

                saveData()
                dialog.dismiss()
                toast("تمت إضافة الموسم")
            }
        }

        dialog.show()
    }

    private fun showSeasonList(anime: Anime) {
        if (anime.seasons.isEmpty()) {
            toast("لا توجد مواسم")
            return
        }

        val names = anime.seasons.map {
            "${it.name} | ${it.watched.ifBlank { "0" }}/${it.episodes.ifBlank { "؟" }}"
        }.toTypedArray()

        AlertDialog.Builder(this)
            .setTitle("مواسم ${anime.name}")
            .setItems(names) { _, which ->
                val season = anime.seasons[which]
                AlertDialog.Builder(this)
                    .setTitle(season.name)
                    .setMessage(
                        "عدد الحلقات: ${season.episodes.ifBlank { "غير محدد" }}\n" +
                        "الحلقات المشاهدة: ${season.watched.ifBlank { "غير محدد" }}"
                    )
                    .setPositiveButton("حسناً", null)
                    .show()
            }
            .setNegativeButton("إغلاق", null)
            .show()
    }

    private fun deleteSeason(anime: Anime) {
        if (anime.seasons.isEmpty()) {
            toast("لا توجد مواسم لحذفها")
            return
        }

        val names = anime.seasons.map { it.name }.toTypedArray()

        AlertDialog.Builder(this)
            .setTitle("اختر الموسم")
            .setItems(names) { _, which ->
                AlertDialog.Builder(this)
                    .setMessage("هل تريد حذف الموسم؟")
                    .setNegativeButton("إلغاء", null)
                    .setPositiveButton("حذف") { _, _ ->
                        val removed = anime.seasons.removeAt(which)
                        deleteImage(removed.image)
                        saveData()
                        toast("تم حذف الموسم")
                    }
                    .show()
            }
            .setNegativeButton("إغلاق", null)
            .show()
    }

    private fun showSettings() {
        heading("الإعدادات")

        val profile = makeCard()
        profile.addView(text("الملف الشخصي", 17f, WHITE, true))
        profile.addView(gap(8))

        val nameField = makeInput("اسمك المستعار", nickname)
        profile.addView(nameField)
        profile.addView(gap(8))

        profile.addView(
            makeButton("اختيار صورة الملف الشخصي", {
                galleryTarget = PICK_PROFILE_IMAGE
                openGallery()
            }, BLUE)
        )

        profile.addView(gap(8))
        profile.addView(
            makeButton("حفظ الملف الشخصي", {
                nickname = nameField.text.toString().trim()
                saveProfile()
                toast("تم حفظ الملف الشخصي")
            })
        )

        content.addView(profile)
        content.addView(gap(13))

        val backup = makeCard()
        backup.addView(text("النسخ الاحتياطي", 17f, WHITE, true))
        backup.addView(gap(7))
        backup.addView(
            text(
                "احفظ بيانات الأنمي والصور في ملف ZIP، ويمكنك استعادتها لاحقاً.",
                13f,
                MUTED
            )
        )
        backup.addView(gap(10))
        backup.addView(
            makeButton("إنشاء نسخة احتياطية", { createBackup() })
        )
        backup.addView(gap(8))
        backup.addView(
            makeButton("استعادة نسخة احتياطية", { restoreBackup() }, BLUE)
        )

        content.addView(backup)
        content.addView(gap(13))

        val about = makeCard()
        about.addView(text("عن التطبيق", 17f, WHITE, true))
        about.addView(text("ذاكرة الأوتاكو", 16f, RED, true))
        about.addView(
            text(
                "مكتبتك الشخصية لتنظيم الأنمي والمواسم والتقييمات.",
                13f,
                MUTED
            )
        )
        about.addView(text("الإصدار 1.0", 12f, MUTED))
        content.addView(about)
    }

    private fun openGallery() {
        try {
            val intent = Intent(
                Intent.ACTION_PICK,
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            ).apply {
                type = "image/*"
            }
            startActivityForResult(intent, galleryTarget)
        } catch (e: Exception) {
            toast("تعذر فتح معرض الصور")
        }
    }

    @Deprecated("Legacy activity result API")
    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ) {
        super.onActivityResult(requestCode, resultCode, data)

        if (resultCode != RESULT_OK || data?.data == null) return

        val uri = data.data!!

        when (requestCode) {
            PICK_ANIME_IMAGE -> {
                draftImage = copyImage(uri)
                toast("تم اختيار صورة الغلاف")
            }

            PICK_SEASON_IMAGE -> {
                seasonDraftImage = copyImage(uri)
                toast("تم اختيار صورة الموسم")
            }

            PICK_PROFILE_IMAGE -> {
                profileImage = copyImage(uri)
                saveProfile()
                renderPage()
                toast("تم اختيار صورة الملف الشخصي")
            }

            EXPORT_BACKUP -> exportBackup(uri)
            IMPORT_BACKUP -> importBackup(uri)
        }
    }

    private fun copyImage(uri: Uri): String {
        return try {
            val folder = File(filesDir, "images")
            if (!folder.exists()) folder.mkdirs()

            val destination = File(
                folder,
                "${UUID.randomUUID()}.jpg"
            )

            val input = contentResolver.openInputStream(uri)
                ?: return ""

            input.use { source ->
                FileOutputStream(destination).use { output ->
                    source.copyTo(output)
                }
            }

            destination.absolutePath
        } catch (e: Exception) {
            toast("تعذر حفظ الصورة")
            ""
        }
    }

    private fun deleteImage(path: String) {
        if (path.isBlank()) return

        try {
            val file = File(path)
            val imageFolder = File(filesDir, "images")

            if (file.exists() && file.parentFile?.canonicalPath ==
                imageFolder.canonicalPath
            ) {
                file.delete()
            }
        } catch (_: Exception) {}
    }

    private fun saveData() {
        try {
            val array = JSONArray()

            animeList.forEach { anime ->
                val obj = JSONObject()

                obj.put("id", anime.id)
                obj.put("name", anime.name)
                obj.put("englishName", anime.englishName)
                obj.put("character", anime.character)
                obj.put("rating", anime.rating)
                obj.put("genres", anime.genres)
                obj.put("status", anime.status)
                obj.put("description", anime.description)
                obj.put("story", anime.story)
                obj.put("year", anime.year)
                obj.put("studio", anime.studio)
                obj.put("notes", anime.notes)
                obj.put("image", anime.image)
                obj.put("favorite", anime.favorite)

                val seasons = JSONArray()

                anime.seasons.forEach { season ->
                    val s = JSONObject()
                    s.put("id", season.id)
                    s.put("name", season.name)
                    s.put("episodes", season.episodes)
                    s.put("watched", season.watched)
                    s.put("image", season.image)
                    seasons.put(s)
                }

                obj.put("seasons", seasons)
                array.put(obj)
            }

            getSharedPreferences(PREFS, MODE_PRIVATE)
                .edit()
                .putString(DATA_KEY, array.toString())
                .apply()

        } catch (e: Exception) {
            toast("تعذر حفظ البيانات")
        }
    }

    private fun loadData() {
        animeList.clear()

        try {
            val raw = getSharedPreferences(PREFS, MODE_PRIVATE)
                .getString(DATA_KEY, "[]") ?: "[]"

            val array = JSONArray(raw)

            for (i in 0 until array.length()) {
                val obj = array.optJSONObject(i) ?: continue

                val anime = Anime(
                    id = obj.optString("id").ifBlank {
                        UUID.randomUUID().toString()
                    },
                    name = obj.optString("name"),
                    englishName = obj.optString("englishName"),
                    character = obj.optString("character"),
                    rating = obj.optString("rating"),
                    genres = obj.optString(
                        "genres",
                        obj.optString("genre")
                    ),
                    status = obj.optString(
                        "status",
                        "لم أشاهده بعد"
                    ),
                    description = obj.optString("description"),
                    story = obj.optString("story"),
                    year = obj.optString("year"),
                    studio = obj.optString("studio"),
                    notes = obj.optString("notes"),
                    image = obj.optString("image"),
                    favorite = obj.optBoolean("favorite", false)
                )

                val seasons = obj.optJSONArray("seasons") ?: JSONArray()

                for (j in 0 until seasons.length()) {
                    val s = seasons.optJSONObject(j) ?: continue

                    anime.seasons.add(
                        AnimeSeason(
                            id = s.optString("id").ifBlank {
                                UUID.randomUUID().toString()
                            },
                            name = s.optString("name"),
                            episodes = s.optString("episodes"),
                            watched = s.optString("watched"),
                            image = s.optString("image")
                        )
                    )
                }

                animeList.add(anime)
            }

        } catch (e: Exception) {
            toast("تعذر قراءة البيانات المحفوظة")
        }
    }

    private fun saveProfile() {
        getSharedPreferences(PREFS, MODE_PRIVATE)
            .edit()
            .putString("nickname", nickname)
            .putString("profile_image", profileImage)
            .apply()
    }

    private fun loadProfile() {
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        nickname = prefs.getString("nickname", "") ?: ""
        profileImage = prefs.getString("profile_image", "") ?: ""
    }

    private fun createBackup() {
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/zip"
            putExtra(Intent.EXTRA_TITLE, "OtakuMemoryBackup.zip")
        }

        try {
            startActivityForResult(intent, EXPORT_BACKUP)
        } catch (e: Exception) {
            toast("تعذر فتح نافذة حفظ الملف")
        }
    }

    private fun restoreBackup() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/zip"
        }

        try {
            startActivityForResult(intent, IMPORT_BACKUP)
        } catch (e: Exception) {
            toast("تعذر فتح نافذة اختيار الملف")
        }
    }

    private fun exportBackup(uri: Uri) {
        try {
            val temp = File(cacheDir, "otaku_backup.zip")

            ZipOutputStream(FileOutputStream(temp)).use { zip ->
                val json = getSharedPreferences(PREFS, MODE_PRIVATE)
                    .getString(DATA_KEY, "[]") ?: "[]"

                zip.putNextEntry(ZipEntry("anime_data.json"))
                zip.write(json.toByteArray(Charsets.UTF_8))
                zip.closeEntry()

                val images = File(filesDir, "images")

                if (images.exists()) {
                    images.listFiles()?.forEach { file ->
                        if (file.isFile) {
                            zip.putNextEntry(
                                ZipEntry("images/${file.name}")
                            )
                            FileInputStream(file).use { it.copyTo(zip) }
                            zip.closeEntry()
                        }
                    }
                }

                val profile = JSONObject()
                    .put("nickname", nickname)
                    .put("profile_image", profileImage)

                zip.putNextEntry(ZipEntry("profile.json"))
                zip.write(profile.toString().toByteArray(Charsets.UTF_8))
                zip.closeEntry()
            }

            val output = contentResolver.openOutputStream(uri)
                ?: throw Exception("Cannot open destination")

            output.use { destination ->
                FileInputStream(temp).use { it.copyTo(destination) }
            }

            toast("تم إنشاء النسخة الاحتياطية")

        } catch (e: Exception) {
            toast("فشل إنشاء النسخة الاحتياطية")
        }
    }

    private fun importBackup(uri: Uri) {
        try {
            val temp = File(cacheDir, "otaku_restore.zip")

            val input = contentResolver.openInputStream(uri)
                ?: throw Exception("Cannot open backup")

            input.use { source ->
                FileOutputStream(temp).use { source.copyTo(it) }
            }

            val imageFolder = File(filesDir, "images")
            if (!imageFolder.exists()) imageFolder.mkdirs()

            var importedJson: String? = null
            var importedProfile: String? = null

            ZipInputStream(FileInputStream(temp)).use { zip ->
                var entry = zip.nextEntry

                while (entry != null) {
                    val safeName = entry.name.replace("\\", "/")

                    if (
                        safeName.startsWith("/") ||
                        safeName.contains("../") ||
                        safeName == ".."
                    ) {
                        zip.closeEntry()
                        entry = zip.nextEntry
                        continue
                    }

                    when {
                        safeName == "anime_data.json" -> {
                            importedJson =
                                zip.readBytes().toString(Charsets.UTF_8)
                        }

                        safeName == "profile.json" -> {
                            importedProfile =
                                zip.readBytes().toString(Charsets.UTF_8)
                        }

                        safeName.startsWith("images/") &&
                            !entry.isDirectory -> {

                            val fileName = File(safeName).name

                            if (fileName.isNotBlank()) {
                                val outputFile = File(imageFolder, fileName)
                                FileOutputStream(outputFile).use {
                                    zip.copyTo(it)
                                }
                            }
                        }
                    }

                    zip.closeEntry()
                    entry = zip.nextEntry
                }
            }

            val json = importedJson
                ?: throw Exception("Backup data not found")

            JSONArray(json)

            val prefs = getSharedPreferences(PREFS, MODE_PRIVATE).edit()
            prefs.putString(DATA_KEY, json)

            if (importedProfile != null) {
                val profile = JSONObject(importedProfile!!)

                nickname = profile.optString("nickname")
                profileImage = profile.optString("profile_image")

                prefs.putString("nickname", nickname)
                prefs.putString("profile_image", profileImage)
            }

            prefs.apply()

            loadData()
            loadProfile()
            renderPage()

            toast("تمت استعادة النسخة الاحتياطية")

        } catch (e: Exception) {
            toast("تعذر استعادة النسخة الاحتياطية. تحقق من الملف.")
        }
    }

    private fun toast(message: String) {
        Toast.makeText(
            this,
            message,
            Toast.LENGTH_SHORT
        ).show()
    }
}